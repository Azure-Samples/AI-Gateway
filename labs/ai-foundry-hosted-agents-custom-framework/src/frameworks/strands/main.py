"""Azure AI Agent Server (Responses protocol),
embedding the Strands Agents SDK as the agent framework.

Requires the following environment variables (see .env):

    AZURE_OPENAI_ENDPOINT     APIM base URL (recommended):
                                                        https://<apim>.azure-api.net/inference/models
                                                        or full chat-completions URL:
                                                        https://<apim>.azure-api.net/inference/models/chat/completions?api-version=2024-05-01-preview
    AZURE_OPENAI_DEPLOYMENT   model name sent as the chat-completions "model" field
    AZURE_OPENAI_API_KEY      required API key used for model calls (or OPENAI_API_KEY)
    AZURE_OPENAI_API_VERSION  optional, defaults to 2024-05-01-preview
    APIM_SUBSCRIPTION_KEY     optional; when set, sent as api-key
  LOG_LEVEL                 optional, defaults to INFO
  STRANDS_LOG_LEVEL         optional, defaults to INFO (Strands SDK's own logger)

Authentication:

        This app uses API key authentication for model calls.
        It does not use managed identity for OpenAI chat-completions requests.

Supports server-side function calling (the "Get Weather" tool and the
"show_internal_environment_variables" debug tool below, both implemented
with ``@tool`` and executed automatically by the Strands agent loop),
incremental token streaming of the model's answer (via
``agent.stream_async()``, piped into ``TextResponse`` as
``response.output_text.delta`` SSE events), image input (input_image content
parts, as inline data: URLs), and multi-turn conversation tracking (via the
Responses protocol's conversation_id / previous_response_id chaining,
surfaced through ResponseContext.get_history() and pre-loaded into the
Strands agent's message history).
"""

import asyncio
import logging
import os
import random
from typing import Sequence

from dotenv import load_dotenv
from openai import AsyncOpenAI

from strands import Agent, tool
from strands.agent.conversation_manager import SlidingWindowConversationManager
from strands.models.openai import OpenAIModel
from strands.types.content import ContentBlock, Messages

from azure.ai.agentserver.responses import (
    CreateResponse,
    ResponseContext,
    ResponsesAgentServerHost,
    TextResponse,
    data_url,
)
from azure.ai.agentserver.responses.models import (
    Item,
    ItemMessage,
    MessageContentInputImageContent,
    MessageContentInputTextContent,
    MessageContentRefusalContent,
    OutputMessageContentOutputTextContent,
    get_content_expanded,
)

load_dotenv()

# --- Logging -----------------------------------------------------------
# A single basicConfig call surfaces logs from our own app logger, the
# Responses hosting layer, and the Strands SDK's agent loop / tool
# invocations, since they all log through the standard `logging` module.
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
)
logging.getLogger("httpx").setLevel(logging.WARNING)  # quiet noisy per-request HTTP logs
logging.getLogger("strands").setLevel(os.environ.get("STRANDS_LOG_LEVEL", "INFO"))

logger = logging.getLogger("strands_responses_app")

app = ResponsesAgentServerHost()


@tool
def show_internal_environment_variables() -> str:
    """Return the internal environment variables that the Strands agent sees, for debugging."""
    env_vars = {k: v for k, v in os.environ.items()}
    return f"{env_vars}"

@tool
def get_weather(city: str) -> str:
    """Get the current weather (temperature) for the given city.

    Args:
        city: The city to look up the weather for.
    """
    temperature_c = random.randint(-5, 35)
    logger.info("tool_call=get_weather city=%s result_c=%s", city, temperature_c)
    return f"The current temperature in {city} is {temperature_c}\u00b0C."


_MODEL: OpenAIModel | None = None


def build_model() -> OpenAIModel:
    global _MODEL
    if _MODEL is None:
        endpoint = os.environ["AZURE_OPENAI_ENDPOINT"]
        deployment = os.environ.get("AZURE_OPENAI_DEPLOYMENT", "gpt-5-mini")
        api_key = (
            os.environ.get("AZURE_OPENAI_API_KEY")
            or os.environ.get("OPENAI_API_KEY")
            or os.environ.get("APIM_SUBSCRIPTION_KEY")
        )
        if not api_key:
            raise RuntimeError(
                "Missing API key. Set AZURE_OPENAI_API_KEY (or OPENAI_API_KEY / APIM_SUBSCRIPTION_KEY)."
            )

        api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-05-01-preview")
        base_url = endpoint.split("?", 1)[0].rstrip("/")
        if base_url.endswith("/chat/completions"):
            base_url = base_url[: -len("/chat/completions")]

        client = AsyncOpenAI(
            base_url=base_url,
            api_key=api_key,
            default_query={"api-version": api_version},
            default_headers={"api-key": api_key},
        )
        
        _MODEL = OpenAIModel(client=client, model_id=deployment)
    return _MODEL


def _message_text(item: Item) -> list[str]:
    """Extract plain text parts from an item's content, handling both the
    typed ``list[MessageContent]`` form and the API's plain-string shorthand
    (``get_content_expanded`` normalizes either into a list). Refusals are
    included too — an assistant declining to answer is still meaningful
    conversation context for the model to see on the next turn.
    """
    texts = []
    for part in get_content_expanded(item):
        if isinstance(part, (MessageContentInputTextContent, OutputMessageContentOutputTextContent)):
            text = getattr(part, "text", None)
            if text:
                texts.append(text)
        elif isinstance(part, MessageContentRefusalContent):
            if part.refusal:
                texts.append(f"[refused to answer: {part.refusal}]")
    return texts


def _history_messages(history: Sequence[Item]) -> Messages:
    """Convert prior conversation turns (from ResponseContext.get_history()) into
    Strands ``Messages`` so the agent starts with full multi-turn context already
    loaded into its conversation history."""
    messages: Messages = []
    for item in history:
        role = getattr(item, "role", None)
        if role not in ("user", "assistant"):
            continue
        texts = _message_text(item)
        if texts:
            role_str = getattr(role, "value", role)
            messages.append({"role": role_str, "content": [{"text": text} for text in texts]})
    return messages


def _extract_image_blocks(items: Sequence[Item]) -> list[ContentBlock]:
    """Pull input images out of the request's input items as Strands ContentBlocks.

    Only inline base64 ``data:`` URLs are supported, since Strands content
    blocks carry raw image bytes rather than remote URLs.
    """
    blocks: list[ContentBlock] = []
    for item in items:
        if not isinstance(item, ItemMessage):
            continue
        for part in item.content or []:
            if not isinstance(part, MessageContentInputImageContent):
                continue
            url = part.image_url
            if not url:
                continue
            if data_url.is_data_url(url):
                media_type = data_url.get_media_type(url) or "image/png"
                image_format = media_type.split("/", 1)[-1] or "png"
                raw_bytes = data_url.decode_bytes(url)
                blocks.append({"image": {"format": image_format, "source": {"bytes": raw_bytes}}})
            else:
                logger.warning("Skipping remote image URL; Strands requires inline image bytes: %s", url)
    return blocks


def build_agent(history: Messages) -> Agent:
    """Wire up a Strands agent with the weather tool, the Azure OpenAI model,
    and prior conversation history pre-loaded so multi-turn context is
    preserved across requests."""
    return Agent(
        model=build_model(),
        tools=[get_weather, show_internal_environment_variables],
        system_prompt=(
            "You are a helpful assistant who can explain concepts, answer questions, and "
            "reason through problems. You have access to two tools - a weather tool that can provide the current "
            "temperature when asked about weather or temperature in a specific place and a tool that can show the internal environment variables that the Strands agent sees, for debugging. "
        ),
        messages=list(history),
        conversation_manager=SlidingWindowConversationManager(window_size=20),
        callback_handler=None,
    )


@app.response_handler
async def handler(
    request: CreateResponse,
    context: ResponseContext,
    cancellation_signal: asyncio.Event,
) -> TextResponse:
    """Run a Strands agent against the request's input text/images and prior
    conversation turns, with server-side function/tool calling support.

    Streams the model's answer token-by-token as it's generated (via Strands'
    ``agent.stream_async()``), so the caller sees incremental
    ``response.output_text.delta`` SSE events instead of waiting for the full
    answer before anything is returned.
    """
    input_items = await context.get_input_items()
    input_text = await context.get_input_text()
    history_items = await context.get_history()

    logger.info(
        "response_id=%s input_chars=%d history_items=%d",
        context.response_id,
        len(input_text or ""),
        len(history_items),
    )

    history_messages = _history_messages(history_items)
    image_blocks = _extract_image_blocks(input_items)

    agent = build_agent(history_messages)

    content: list[ContentBlock] = [{"text": input_text}] if input_text else []
    content.extend(image_blocks)

    async def _generate_tokens():
        # Bridge the host's cooperative cancellation signal to the agent's own
        # cancel() so a client disconnect/timeout stops in-flight model/tool calls.
        async def _watch_cancellation() -> None:
            await cancellation_signal.wait()
            logger.warning("response_id=%s cancellation requested; stopping agent", context.response_id)
            agent.cancel()

        watcher = asyncio.create_task(_watch_cancellation())
        try:
            async for event in agent.stream_async(content or None):
                text = event.get("data")
                if isinstance(text, str) and text:
                    yield text

                result = event.get("result")
                if result is not None:
                    logger.info(
                        "response_id=%s stop_reason=%s",
                        context.response_id,
                        result.stop_reason,
                    )
        except Exception:
            logger.exception("response_id=%s agent invocation failed", context.response_id)
            raise
        finally:
            watcher.cancel()

    return TextResponse(context, request, text=_generate_tokens())


if __name__ == "__main__":
    app.run()
