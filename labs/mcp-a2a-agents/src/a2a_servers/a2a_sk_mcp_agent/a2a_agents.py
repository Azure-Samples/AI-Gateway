import logging
import os

import abc
from collections.abc import AsyncIterable
from typing import TYPE_CHECKING, Annotated, Any, Literal

from pydantic import BaseModel
from semantic_kernel.agents import ChatCompletionAgent, ChatHistoryAgentThread
from semantic_kernel.connectors.ai.open_ai import (
    OpenAIChatCompletion,
    OpenAIChatPromptExecutionSettings,
    AzureChatCompletion
)
from semantic_kernel.contents import (
    FunctionCallContent,
    FunctionResultContent,
    StreamingChatMessageContent,
    StreamingTextContent,
)
from semantic_kernel.functions import kernel_function
from semantic_kernel.functions.kernel_arguments import KernelArguments

from semantic_kernel.connectors.ai.chat_completion_client_base import ChatCompletionClientBase

import asyncio
from semantic_kernel.connectors.mcp import MCPSsePlugin

if TYPE_CHECKING:
    from semantic_kernel.contents import ChatMessageContent

logger = logging.getLogger(__name__)

# region Response Format


class ResponseFormat(BaseModel):
    """A Response Format model to direct how the model should respond."""

    status: Literal['input_required', 'completed', 'error'] = 'input_required'
    message: str


# endregion

class AbstractAgent(abc.ABC):
    """
    A minimal, implementation-agnostic contract for any assistant agent using any framework.

    Concrete subclasses may wrap Semantic Kernel, LangChain, your own
    in-house stack, or even a local LLM – as long as they satisfy this API.
    """

    #: MIME types that downstream code can rely on receiving.
    SUPPORTED_CONTENT_TYPES: list[str] = ['text', 'text/plain']

    # ------------------------------------------------------------------ #
    #  Lifecycle helpers
    # ------------------------------------------------------------------ #

    async def __aenter__(self):
        # subclasses may override; by default do nothing
        return self

    async def __aexit__(self, exc_type, exc, tb):
        # subclasses may override; by default do nothing
        return False                     # propagate any exception

    @abc.abstractmethod
    async def invoke(self, user_input: str, session_id: str) -> dict[str, Any]:  # noqa: D401
        """
        Handle a *single-shot* request.

        Implementations **must** be idempotent: calling twice with the same
        `(user_input, session_id)` pair should yield the same logical answer,
        even if the underlying LLM re-generates new text.
        """

# region Semantic Kernel Agent


class SemanticKernelAgent(AbstractAgent):
    """Wraps Semantic Kernel-based agents to handle tasks."""

    # agent: ChatCompletionAgent
    # thread: ChatHistoryAgentThread = None
    # mcp_plugin: MCPSsePlugin = None
    # mcp_url: str = None


    SUPPORTED_CONTENT_TYPES = ['text', 'text/plain']

    def __init__(self, mcp_url: str, title: str,
                 oai_client: ChatCompletionClientBase):
        # just stash config – DO NOT build anything heavy here
        self._mcp_url   = mcp_url.rstrip('/')
        self._title     = title
        self._oai_client = oai_client

        # runtime attributes populated in __aenter__
        self.mcp_plugin: MCPSsePlugin | None = None
        self.agent:      ChatCompletionAgent | None = None
        self.thread:     ChatHistoryAgentThread | None = None

    # ------------------------------------------------------------------
    # async context-manager wires the plugin correctly
    async def __aenter__(self) -> "SemanticKernelAgent":
        # 1. open the SSE plugin
        self.mcp_plugin = MCPSsePlugin(
            name        = self._title,
            url         = self._mcp_url,
            description = f"{self._title} Plugin",
        )
        await self.mcp_plugin.__aenter__()            # <-- crucial

        # 2. build the SK agent (note the **singular** `plugin=`)
        self.agent = ChatCompletionAgent(
            service = self._oai_client,
            name    = f"{self._title}_agent",
            instructions = (
                f"You are a helpful assistant for {self._title} queries."
            ),
            plugins  = [self.mcp_plugin],    
            arguments = KernelArguments(
                settings = OpenAIChatPromptExecutionSettings(
                    response_format = ResponseFormat,
                )
            ),
        )
        return self

    async def __aexit__(self, exc_type, exc, tb):
        if self.thread:
            await self.thread.delete()
            self.thread = None
        if self.mcp_plugin:
            await self.mcp_plugin.__aexit__(exc_type, exc, tb)
        return False
    

    # ------------------------------------------------------------------
    async def invoke(self, user_input: str, session_id: str) -> dict[str, Any]:
        """Handle synchronous tasks (like tasks/send).

        Args:
            user_input (str): User input message.
            session_id (str): Unique identifier for the session.

        Returns:
            dict: A dictionary containing the content, task completion status, and user input requirement.
        """
        await self._ensure_thread_exists(session_id)

        # Use SK's get_response for a single shot
        response = await self.agent.get_response(
            messages=user_input,
            thread=self.thread,
        )
        return self._get_agent_response(response.content)

    async def stream(
        self,
        user_input: str,
        session_id: str,
    ) -> AsyncIterable[dict[str, Any]]:
        """For streaming tasks we yield the SK agent's invoke_stream progress.

        Args:
            user_input (str): User input message.
            session_id (str): Unique identifier for the session.

        Yields:
            dict: A dictionary containing the content, task completion status,
            and user input requirement.
        """
        await self._ensure_thread_exists(session_id)

        plugin_notice_seen = False
        plugin_event = asyncio.Event()

        text_notice_seen = False
        chunks: list[StreamingChatMessageContent] = []

        async def _handle_intermediate_message(
            message: 'ChatMessageContent',
        ) -> None:
            """Handle intermediate messages from the agent."""
            nonlocal plugin_notice_seen
            if not plugin_notice_seen:
                plugin_notice_seen = True
                plugin_event.set()
            # An example of handling intermediate messages during function calling
            for item in message.items or []:
                if isinstance(item, FunctionResultContent):
                    print(
                        f'############ Function Result:> {item.result} for function: {item.name}'
                    )
                elif isinstance(item, FunctionCallContent):
                    print(
                        f'############ Function Call:> {item.name} with arguments: {item.arguments}'
                    )
                else:
                    print(f'############ Message:> {item}')

        async for chunk in self.agent.invoke_stream(
            messages=user_input,
            thread=self.thread,
            on_intermediate_message=_handle_intermediate_message,
        ):
            if plugin_event.is_set():
                yield {
                    'is_task_complete': False,
                    'require_user_input': False,
                    'content': 'Processing function calls...',
                }
                plugin_event.clear()

            if any(isinstance(i, StreamingTextContent) for i in chunk.items):
                if not text_notice_seen:
                    yield {
                        'is_task_complete': False,
                        'require_user_input': False,
                        'content': 'Building the output...',
                    }
                    text_notice_seen = True
                chunks.append(chunk.message)

        if chunks:
            yield self._get_agent_response(sum(chunks[1:], chunks[0]))

    def _get_agent_response(
        self, message: 'ChatMessageContent'
    ) -> dict[str, Any]:
        """Extracts the structured response from the agent's message content.

        Args:
            message (ChatMessageContent): The message content from the agent.

        Returns:
            dict: A dictionary containing the content, task completion status, and user input requirement.
        """
        structured_response = ResponseFormat.model_validate_json(
            message.content
        )

        default_response = {
            'is_task_complete': False,
            'require_user_input': True,
            'content': 'We are unable to process your request at the moment. Please try again.',
        }

        if isinstance(structured_response, ResponseFormat):
            response_map = {
                'input_required': {
                    'is_task_complete': False,
                    'require_user_input': True,
                },
                'error': {
                    'is_task_complete': False,
                    'require_user_input': True,
                },
                'completed': {
                    'is_task_complete': True,
                    'require_user_input': False,
                },
            }

            response = response_map.get(structured_response.status)
            if response:
                return {**response, 'content': structured_response.message}

        return default_response

    async def _ensure_thread_exists(self, session_id: str) -> None:
        """Ensure the thread exists for the given session ID.

        Args:
            session_id (str): Unique identifier for the session.
        """
        if self.thread is None or self.thread.id != session_id:
            await self.thread.delete() if self.thread else None
            self.thread = ChatHistoryAgentThread(thread_id=session_id)


# endregion
