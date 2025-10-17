# ------------------------------------------------------------------------
# a2a_agents.py  – resilient version (May 2025)
# ------------------------------------------------------------------------
import abc
import asyncio
import logging
import random
from collections.abc import AsyncIterable
from typing import TYPE_CHECKING, Any, Callable, Literal

from pydantic import BaseModel
from semantic_kernel.agents import ChatCompletionAgent, ChatHistoryAgentThread
from semantic_kernel.connectors.ai.chat_completion_client_base import (
    ChatCompletionClientBase,
)
from semantic_kernel.connectors.ai.open_ai import (
    AzureChatCompletion,
    OpenAIChatPromptExecutionSettings,
)
from semantic_kernel.connectors.mcp import MCPStreamableHttpPlugin
from semantic_kernel.contents import (
    FunctionCallContent,
    FunctionResultContent,
    StreamingChatMessageContent,
    StreamingTextContent,
)
from semantic_kernel.functions.kernel_arguments import KernelArguments

# websockets errors bubbled up by MCPStreamableHttpPlugin
from websockets.exceptions import ConnectionClosedError, ConnectionClosedOK

if TYPE_CHECKING:
    from semantic_kernel.contents import ChatMessageContent

# ──────────────────────────────────────────────────────────────────────────
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# region Response Format ---------------------------------------------------
class AgentResponse(BaseModel):
    status: Literal["input_required", "completed", "error"] = "input_required"
    message: str
# endregion


# ──────────────────────────────────────────────────────────────────────────
class AbstractAgent(abc.ABC):
    SUPPORTED_CONTENT_TYPES = ["text", "text/plain"]

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    @abc.abstractmethod
    async def invoke(self, user_input: str, session_id: str) -> dict[str, Any]:
        ...


# ──────────────────────────────────────────────────────────────────────────
class SemanticKernelAgent(AbstractAgent):
    """Semantic-Kernel agent with automatic SSE reconnect + retries."""

    # ------------------------------------------------------------------ #
    # Construction / context-manager
    # ------------------------------------------------------------------ #
    def __init__(
        self,
        mcp_url: str,
        title: str,
        oai_client: ChatCompletionClientBase,
        *,
        max_attempts: int = 3,
        base_delay: float = 0.5,
        max_delay: float = 5.0,
    ):
        self._mcp_url = mcp_url.rstrip("/")
        self._title = title
        self._oai_client = oai_client

        self._max_attempts = max_attempts
        self._base_delay = base_delay
        self._max_delay = max_delay

        self.mcp_plugin: MCPStreamableHttpPlugin | None = None
        self.agent: ChatCompletionAgent | None = None
        self.thread: ChatHistoryAgentThread | None = None

    async def __aenter__(self):
        await self._open_plugin_and_agent()
        return self

    async def __aexit__(self, exc_type, exc, tb):
        await self._close_everything(exc_type, exc, tb)
        return False

    # ------------------------------------------------------------------ #
    # Public API: invoke / stream
    # ------------------------------------------------------------------ #
    async def invoke(
        self, user_input: str, session_id: str
    ) -> dict[str, Any]:
        await self._ensure_thread_exists(session_id)

        async def _call():
            response = await self.agent.get_response(  # type: ignore[union-attr]
                messages=user_input,
                thread=self.thread,
            )
            return self._get_agent_response(response.content)

        return await self._retry_coro("invoke", _call)

    async def stream(
        self, user_input: str, session_id: str
    ) -> AsyncIterable[dict[str, Any]]:
        await self._ensure_thread_exists(session_id)

        async def _stream_call():
            plugin_notice_seen = False
            plugin_event = asyncio.Event()
            text_notice_seen = False
            chunks: list[StreamingChatMessageContent] = []

            async def _handle_intermediate(message: "ChatMessageContent"):
                nonlocal plugin_notice_seen
                if not plugin_notice_seen:
                    plugin_notice_seen = True
                    plugin_event.set()
                for item in message.items or []:
                    if isinstance(item, FunctionResultContent):
                        logger.debug("Function result %s", item.result)
                    elif isinstance(item, FunctionCallContent):
                        logger.debug("Function call %s", item.name)

            async for chunk in self.agent.invoke_stream(  # type: ignore[union-attr]
                messages=user_input,
                thread=self.thread,
                on_intermediate_message=_handle_intermediate,
            ):
                if plugin_event.is_set():
                    yield {
                        "is_task_complete": False,
                        "require_user_input": False,
                        "content": "Processing function calls…",
                    }
                    plugin_event.clear()

                if any(isinstance(i, StreamingTextContent) for i in chunk.items):
                    if not text_notice_seen:
                        yield {
                            "is_task_complete": False,
                            "require_user_input": False,
                            "content": "Building the output…",
                        }
                        text_notice_seen = True
                    chunks.append(chunk.message)

            if chunks:
                yield self._get_agent_response(sum(chunks[1:], chunks[0]))

        async for item in self._retry_gen("stream", _stream_call):
            yield item

    # ------------------------------------------------------------------ #
    # Retry helpers (separate for coro vs generator)
    # ------------------------------------------------------------------ #
    async def _retry_coro(self, op_name: str, factory: Callable[[], Any]):
        for attempt in range(1, self._max_attempts + 1):
            try:
                return await factory()
            except (ConnectionClosedError, ConnectionClosedOK) as ex:
                await self._backoff_or_raise(op_name, attempt, ex)

    async def _retry_gen(self, op_name: str, factory: Callable[[], Any]):
        for attempt in range(1, self._max_attempts + 1):
            try:
                async for item in factory():
                    yield item
                return
            except (ConnectionClosedError, ConnectionClosedOK) as ex:
                await self._backoff_or_raise(op_name, attempt, ex)

    async def _backoff_or_raise(self, op_name: str, attempt: int, ex: Exception):
        logger.warning(
            "%s: SSE dropped (attempt %d/%d): %s",
            op_name,
            attempt,
            self._max_attempts,
            ex,
        )
        if attempt == self._max_attempts:
            raise
        await self._reconnect_plugin()
        delay = min(self._max_delay, self._base_delay * 2 ** (attempt - 1))
        delay *= random.uniform(0.8, 1.2)  # jitter
        await asyncio.sleep(delay)

    # ------------------------------------------------------------------ #
    # Plugin / agent (re)initialisation
    # ------------------------------------------------------------------ #
    async def _reconnect_plugin(self):
        logger.info("Reconnecting MCPSsePlugin for %s…", self._title)
        await self._close_everything(None, None, None)
        await self._open_plugin_and_agent()

    async def _open_plugin_and_agent(self):
        self.mcp_plugin = MCPStreamableHttpPlugin(
            name=self._title,
            url=self._mcp_url,
            description=f"{self._title} Plugin",
        )
        await self.mcp_plugin.__aenter__()

        self.agent = ChatCompletionAgent(
            service=self._oai_client,
            name=f"{self._title}_agent",
            instructions=f"You are a helpful assistant for {self._title}.",
            plugins=[self.mcp_plugin],
            arguments=KernelArguments(
                settings=OpenAIChatPromptExecutionSettings(
                    response_format=AgentResponse,
                )
            ),
        )
        logger.info("MCPSsePlugin connected (%s).", self._title)

    async def _close_everything(self, exc_type, exc, tb):
        if self.thread:
            try:
                await self.thread.delete()
            except Exception as err:
                logger.debug("Thread delete failed: %s", err)
            self.thread = None

        if self.mcp_plugin:
            try:
                await self.mcp_plugin.__aexit__(exc_type, exc, tb)
            except Exception as err:
                logger.debug("Plugin close failed: %s", err)
            self.mcp_plugin = None
            self.agent = None

    # ------------------------------------------------------------------ #
    # Utility helpers
    # ------------------------------------------------------------------ #
    async def _ensure_thread_exists(self, session_id: str):
        if self.thread is None or self.thread.id != session_id:
            if self.thread:
                await self.thread.delete()
            self.thread = ChatHistoryAgentThread(thread_id=session_id)

    def _get_agent_response(self, message: "ChatMessageContent") -> dict[str, Any]:
        try:
            structured = AgentResponse.model_validate_json(message.content)
        except Exception:
            return {
                "is_task_complete": False,
                "require_user_input": True,
                "content": "Unparseable response – please try again.",
            }

        mapping = {
            "input_required": {"is_task_complete": False, "require_user_input": True},
            "error": {"is_task_complete": False, "require_user_input": True},
            "completed": {"is_task_complete": True, "require_user_input": False},
        }
        meta = mapping.get(structured.status)
        return {**meta, "content": structured.message} if meta else {
            "is_task_complete": False,
            "require_user_input": True,
            "content": structured.message,
        }


# ------------------------------------------------------------------------
# End of file
# ------------------------------------------------------------------------
