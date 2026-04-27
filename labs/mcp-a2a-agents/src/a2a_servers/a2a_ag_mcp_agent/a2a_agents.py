# -----------------------------------------------------------------------------
# autogen_mcp_agent.py – AutoGen-based agent that talks to a remote MCP server
# -----------------------------------------------------------------------------
# 26 May 2025 – updated: allow caller‑supplied *Azure* (or any) OpenAI client
# -----------------------------------------------------------------------------
"""A resilient, AutoGen‑based wrapper for calling a remote MCP server.

Key features
~~~~~~~~~~~~
* **Pluggable model client** – pass any ``ChatCompletionClient`` instance via
  ``oai_client=…``. Works with
  ``AzureOpenAIChatCompletionClient`` as well as the plain ``OpenAIChatCompletionClient``.
* Auto‑discovers tools from an MCP Streamable endpoint and registers them with the
  AssistantAgent.
* Structured JSON replies validated against ``AgentResponse`` so the caller can
  keep using the existing ``is_task_complete`` / ``require_user_input`` flags.
* Jittered exponential back‑off for transient network hiccups.

Usage example (Azure)
=====================
```python
from autogen_mcp_agent import AutoGenAgent  # alias provided for convenience
from autogen_ext.models.openai import AzureOpenAIChatCompletionClient

ag_weather_agent = AutoGenAgent(
    mcp_url=f"{APIM_GATEWAY_URL}{MCP_URL}",
    title=TITLE,
    oai_client=AzureOpenAIChatCompletionClient(
        azure_endpoint=APIM_GATEWAY_URL,
        api_key=APIM_SUBSCRIPTION_KEY,
        api_version=OPENAI_API_VERSION,
        azure_deployment=OPENAI_DEPLOYMENT_NAME,
        model=OPENAI_DEPLOYMENT_NAME,
    ),
)
```
"""
from __future__ import annotations

import abc
import asyncio
import logging
import random
from collections.abc import AsyncIterable, Awaitable
from typing import Any, Callable, Literal, Optional, Union

from pydantic import BaseModel

# AutoGen ▸ AgentChat
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.messages import StructuredMessage, TextMessage, ModelClientStreamingChunkEvent, ToolCallExecutionEvent, ToolCallRequestEvent, ToolCallSummaryMessage

# AutoGen ▸ Extensions ▸ OpenAI model clients
from autogen_ext.models.openai import (
    OpenAIChatCompletionClient,
    AzureOpenAIChatCompletionClient,
)

# AutoGen ▸ Extensions ▸ MCP helpers
from autogen_ext.tools.mcp import (
    StreamableHttpServerParams,
    mcp_server_tools,
    create_mcp_server_session,
)
from autogen_core import CancellationToken

# ---------------------------------------------------------------------------
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# ---------------------------------------------------------------------------
# Response format
# ---------------------------------------------------------------------------
class AgentResponse(BaseModel):
    status: Literal["input_required", "completed", "error"]
    message: str


_MAPPING = {
    "input_required": {"is_task_complete": False, "require_user_input": True},
    "error": {"is_task_complete": False, "require_user_input": True},
    "completed": {"is_task_complete": True, "require_user_input": False},
}


class AbstractAgent(abc.ABC):
    SUPPORTED_CONTENT_TYPES = ["text", "text/plain"]

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    @abc.abstractmethod
    async def invoke(self, user_input: str, session_id: str) -> dict[str, Any]:
        ...

    @abc.abstractmethod
    async def stream(
        self, user_input: str, session_id: str
    ) -> AsyncIterable[dict[str, Any]]:
        ...


# ---------------------------------------------------------------------------
class AutoGenAgent(AbstractAgent):
    """AutoGen agent that consumes an MCP Streamable endpoint."""

    def __init__(
        self,
        *,
        mcp_url: str,
        title: str = "AutoGen_MCP_Agent",
        # Either pass a ready‑made ChatCompletion client …
        oai_client: Optional[
            Union[OpenAIChatCompletionClient, AzureOpenAIChatCompletionClient]
        ] = None,
        # …or let the agent build a default OpenAIChatCompletionClient via these:
        model: str = "gpt-4o",
        api_key: str | None = None,
        # Network/auth
        http_headers: dict[str, str] | None = None,
        # Retry behaviour
        max_attempts: int = 3,
        base_delay: float = 0.5,
        max_delay: float = 5.0,
    ) -> None:
        self._server_params = StreamableHttpServerParams(url=mcp_url, headers=http_headers)
        self._title = title

        self._model_client: Union[
            OpenAIChatCompletionClient, AzureOpenAIChatCompletionClient
        ] | None = oai_client
        self._fallback_model_name = model
        self._fallback_api_key = api_key or ""

        self._max_attempts = max_attempts
        self._base_delay = base_delay
        self._max_delay = max_delay

        self._session = None  # MCP client session
        self._agent: AssistantAgent | None = None

    # ------------------------------------------------------------------ #
    # Context‑manager helpers
    async def __aenter__(self):
        await self._open_session_and_agent()
        return self

    async def __aexit__(self, exc_type, exc, tb):
        await self._close_everything(exc_type, exc, tb)
        return False

    # ------------------------------------------------------------------ #
    # Public API
    async def invoke(self, user_input: str, session_id: str) -> dict[str, Any]:
        async def _do():
            token = CancellationToken()
            result = await self._agent.run(task=user_input, cancellation_token=token)
            return self._extract_response(result.messages[-1])

        return await self._retry("invoke", _do)

    async def stream(
        self, user_input: str, session_id: str
    ) -> AsyncIterable[dict[str, Any]]:
        async def _generator():
            token = CancellationToken()
            async for event in self._agent.run_stream(
                task=user_input, cancellation_token=token
            ):
                # print(f"+++++++++++++++++++++++ {event.model_dump_json()}")
                if isinstance(event, ModelClientStreamingChunkEvent):
                    yield {
                        "is_task_complete": False,
                        "require_user_input": False,
                        "content": event.delta or "…",
                    }
                    continue

                if isinstance(event, TextMessage):
                    yield {
                        "is_task_complete": False,
                        "require_user_input": False,
                        "content": event.content or "…",
                    }
                    continue

                if isinstance(event, (ToolCallRequestEvent, ToolCallExecutionEvent, ToolCallSummaryMessage)):
                    # You can emit a progress ping here or just ignore it
                    continue

                if isinstance(event, StructuredMessage):
                    yield self._extract_response(event)
                    return        # <- closes the generator cleanly

                if hasattr(event, "messages"):
                    yield self._extract_response(event.messages[-1])
                    return


        async for item in self._retry_gen("stream", _generator):
            yield item

    # ------------------------------------------------------------------ #
    # Retry helpers
    async def _retry(
        self, name: str, coro_factory: Callable[[], Awaitable[Any]]
    ) -> Any:
        for attempt in range(1, self._max_attempts + 1):
            try:
                return await coro_factory()
            except Exception as ex:  # broad but logged
                await self._backoff_or_raise(name, attempt, ex)

    async def _retry_gen(
        self, name: str, gen_factory: Callable[[], AsyncIterable[Any]]
    ) -> AsyncIterable[Any]:
        for attempt in range(1, self._max_attempts + 1):
            try:
                async for item in gen_factory():
                    yield item
                return
            except Exception as ex:
                await self._backoff_or_raise(name, attempt, ex)

    async def _backoff_or_raise(self, op_name: str, attempt: int, ex: Exception):
        logger.warning(
            "%s: transient error (attempt %d/%d): %s",
            op_name,
            attempt,
            self._max_attempts,
            ex,
        )
        if attempt == self._max_attempts:
            raise
        delay = min(self._max_delay, self._base_delay * 2 ** (attempt - 1))
        delay *= random.uniform(0.8, 1.2)
        await asyncio.sleep(delay)

    # ------------------------------------------------------------------ #
    # ------------------------------------------------------------------ #
    # Initialisation / teardown
    async def _open_session_and_agent(self):
        logger.info("Connecting to MCP server at %s…", self._server_params.url)

        # The factory returns an *async context manager*, not the session itself.
        # We have to keep a reference to it so we can close it later.
        self._session_cm = create_mcp_server_session(self._server_params)
        self._session = await self._session_cm.__aenter__()
        await self._session.initialize()

        tools = await mcp_server_tools(self._server_params, session=self._session)
        for tool in tools:
            tool._strict = True
        logger.info("%d tools discovered.", len(tools))

        if not self._model_client:
            self._model_client = OpenAIChatCompletionClient(
                model=self._fallback_model_name,
                api_key=self._fallback_api_key,
                response_format=AgentResponse,
            )
        else:
            self._model_client.response_format = AgentResponse  # type: ignore[attr-defined]

        self._agent = AssistantAgent(
            name=self._title,
            model_client=self._model_client,
            tools=tools,  # type: ignore[arg-type]
            output_content_type=AgentResponse,
            reflect_on_tool_use=True,
            system_message=(
                f"You are a specialised assistant for {self._title}. "
            ),
        )

    async def _close_everything(self, exc_type, exc, tb):
        if getattr(self, "_session_cm", None):
            await self._session_cm.__aexit__(exc_type, exc, tb)
            self._session_cm = None
            self._session = None
        self._agent = None

    def _extract_response(self, message):  # type: ignore[any-untyped-call]
        print(f"Final: {message}")
        if isinstance(message, StructuredMessage):
            payload: AgentResponse = message.content  # type: ignore[assignment]
            meta = _MAPPING.get(payload.status, _MAPPING["input_required"])
            return {**meta, "content": payload.message}
        return {
            "is_task_complete": True,
            "require_user_input": False,
            "content": getattr(message, "to_text", lambda: str(message))(),
        }
