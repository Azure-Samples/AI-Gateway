"""
Weather Search Hosted Agent
Combines Bing Grounding (web search) and Weather MCP tools via Azure AI Foundry.
Uses Azure OpenAI via APIM as the inference backend.
Designed for deployment to Azure Container Apps as an AI Foundry Hosted Agent.
"""

import os
from dotenv import load_dotenv

from agent_framework.azure import AzureOpenAIChatClient
from azure.ai.agentserver.agentframework import from_agent_framework, FoundryToolsChatMiddleware
from azure.identity import DefaultAzureCredential

# Load .env file for local development
load_dotenv(override=True)

debug = os.environ.get("DEBUG", "false").lower() == "true"
if debug:
    print("Debug mode enabled - setting logging to DEBUG level")
    import logging
    logging.basicConfig(level=logging.DEBUG)
    logging.getLogger("azure").setLevel(logging.DEBUG)
    logging.getLogger("agent_framework").setLevel(logging.DEBUG)

def main() -> None:
    required_env_vars = [
        "AZURE_OPENAI_ENDPOINT",
        "AZURE_OPENAI_CHAT_DEPLOYMENT_NAME",
        "AZURE_OPENAI_KEY",
        "AZURE_AI_PROJECT_ENDPOINT",
    ]
    for env_var in required_env_vars:
        assert env_var in os.environ and os.environ[env_var], (
            f"{env_var} environment variable must be set."
        )

    api_key = os.environ.get("AZURE_OPENAI_KEY")

    # Create credential inside main() to ensure it is bound to the running event loop.
    # Creating DefaultAzureCredential at module level causes "attached to a different loop"
    # errors after long idle periods when the event loop is recycled.
    credential = DefaultAzureCredential()

    # Build the tools list - both Bing Grounding and Weather MCP are optional
    tools: list[dict] = []

    if bing_connection_id := os.environ.get("BING_GROUNDING_CONNECTION_ID"):
        tools.append({
            "type": "bing_grounding",
            "connection_id": bing_connection_id,
        })
        print("Bing Grounding tool added to agent.")

    if weather_mcp_connection_id := os.environ.get("WEATHER_MCP_CONNECTION_ID"):
        tools.append({
            "type": "mcp",
            "project_connection_id": weather_mcp_connection_id,
        })
        print("Weather MCP tool added to agent.")

    # Use AzureOpenAIChatClient so the agent calls inference via APIM gateway
    chat_client = AzureOpenAIChatClient(
        api_key=api_key,
        middleware=FoundryToolsChatMiddleware(tools),
    )

    agent = chat_client.create_agent(
        name="WeatherSearchAgent",
        model=os.environ["AZURE_OPENAI_CHAT_DEPLOYMENT_NAME"],
        instructions=(
            "You are a helpful travel and weather assistant. You can:\n"
            "1. Search the web for current news and information using Bing\n"
            "2. Get real-time weather data for cities worldwide\n\n"
            "When answering weather questions, use the weather tool to fetch "
            "live data. For general questions, use the Bing search tool. "
            "Always provide accurate, helpful, and well-sourced answers."
        ),
        allow_multiple_tool_calls=True,
    )

    print("WeatherSearchAgent running on http://localhost:8088")
    from_agent_framework(agent).run()


if __name__ == "__main__":
    main()
