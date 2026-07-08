"""Azure AI Agent Server (Responses protocol),
embedding Pydantic AI as the agent framework.

Requires the following environment variables (see .env):

  AZURE_OPENAI_ENDPOINT     e.g. https://<resource>.openai.azure.com/
  AZURE_OPENAI_DEPLOYMENT   deployment name, e.g. gpt-5-mini
  AZURE_OPENAI_API_VERSION  optional, defaults to 2024-12-01-preview
  LOG_LEVEL                 optional, defaults to INFO

Authentication:

  This app uses DefaultAzureCredential (Microsoft Entra ID), not API keys.
  The runtime identity (user, service principal, or managed identity) must have
  Azure OpenAI data-plane access (for example, the Cognitive Services OpenAI User role)
  on the target Azure OpenAI resource.
"""

import asyncio
import logging
import os
import random
from typing import Sequence

from dotenv import load_dotenv
from openai import AsyncAzureOpenAI

from pydantic_ai import Agent
from pydantic_ai.models.openai import OpenAIChatModel
from pydantic_ai.providers.openai import OpenAIProvider

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.ai.agentserver.responses import (
    CreateResponse,
    ResponseContext,
    ResponsesAgentServerHost,
    TextResponse,
)
from azure.ai.agentserver.responses.models import (
    Item,
    MessageContentInputTextContent,
    MessageContentRefusalContent,
    OutputMessageContentOutputTextContent,
    get_content_expanded,
)

load_dotenv()

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
)
logging.getLogger("httpx").setLevel(logging.WARNING)

logger = logging.getLogger("pydantic_ai_responses_app")

app = ResponsesAgentServerHost()

_AGENT: Agent | None = None


def _message_text(item: Item) -> list[str]:
    texts: list[str] = []
    for part in get_content_expanded(item):
        if isinstance(part, (MessageContentInputTextContent, OutputMessageContentOutputTextContent)):
            text = getattr(part, "text", None)
            if text:
                texts.append(text)
        elif isinstance(part, MessageContentRefusalContent):
            if part.refusal:
                texts.append(f"[refused to answer: {part.refusal}]")
    return texts


def _build_prompt(history: Sequence[Item], input_text: str) -> str:
    history_lines: list[str] = []
    for item in history:
        role = getattr(item, "role", None)
        if role not in ("user", "assistant"):
            continue
        role_str = getattr(role, "value", role)
        for text in _message_text(item):
            history_lines.append(f"{role_str}: {text}")

    prompt_parts: list[str] = []
    if history_lines:
        prompt_parts.append("Conversation so far:")
        prompt_parts.extend(history_lines)
    if input_text:
        prompt_parts.append(f"user: {input_text}")
    return "\n".join(prompt_parts) if prompt_parts else "Hello"


def build_agent() -> Agent:
    global _AGENT
    if _AGENT is None:
        endpoint = os.environ["AZURE_OPENAI_ENDPOINT"]
        deployment = os.environ.get("AZURE_OPENAI_DEPLOYMENT", "gpt-5-mini")
        api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-12-01-preview")

        token_provider = get_bearer_token_provider(
            DefaultAzureCredential(),
            "https://cognitiveservices.azure.com/.default",
        )

        client = AsyncAzureOpenAI(
            azure_endpoint=endpoint,
            api_version=api_version,
            azure_ad_token_provider=token_provider,
        )

        model = OpenAIChatModel(
            deployment,
            provider=OpenAIProvider(openai_client=client),
        )

        _AGENT = Agent(
            model,
            instructions=(
                "You are a helpful assistant who can explain concepts, answer questions, and "
                "reason through problems. You have access to two tools: get_weather for weather "
                "questions and show_internal_environment_variables for debugging."
            ),
        )

        @_AGENT.tool_plain
        def get_weather(city: str) -> str:
            temperature_c = random.randint(-5, 35)
            logger.info("tool_call=get_weather city=%s result_c=%s", city, temperature_c)
            return f"The current temperature in {city} is {temperature_c} deg C."

        @_AGENT.tool_plain
        def show_internal_environment_variables() -> str:
            return str(dict(os.environ))

    return _AGENT


@app.response_handler
async def handler(
    request: CreateResponse,
    context: ResponseContext,
    cancellation_signal: asyncio.Event,
) -> TextResponse:
    input_text = await context.get_input_text()
    history_items = await context.get_history()

    logger.info(
        "response_id=%s input_chars=%d history_items=%d",
        context.response_id,
        len(input_text or ""),
        len(history_items),
    )

    agent = build_agent()
    prompt = _build_prompt(history_items, input_text or "")

    async def _generate_tokens():
        previous = ""
        async with agent.run_stream(prompt) as run:
            async for chunk in run.stream_text():
                if cancellation_signal.is_set():
                    logger.warning("response_id=%s cancellation requested", context.response_id)
                    break

                if not isinstance(chunk, str) or not chunk:
                    continue

                # Convert cumulative stream_text output into incremental deltas.
                if chunk.startswith(previous):
                    delta = chunk[len(previous) :]
                else:
                    delta = chunk

                previous = chunk
                if delta:
                    yield delta

    return TextResponse(context, request, text=_generate_tokens())


if __name__ == "__main__":
    app.run()
