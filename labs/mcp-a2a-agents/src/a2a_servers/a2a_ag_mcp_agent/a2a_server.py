import logging
import httpx

from starlette.applications import Starlette     # A2A wraps Starlette
from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore, InMemoryPushNotifier
from a2a.types import AgentCapabilities, AgentCard, AgentSkill

from a2a_agent_exec import A2ALabAgentExecutor
from a2a_agents import AutoGenAgent

from autogen_ext.models.openai import AzureOpenAIChatCompletionClient
# ------------------------------------------------------------------------

log = logging.getLogger(__name__)


import os

TITLE                   = os.environ.get("TITLE", "Weather")
MCP_URL                 = os.environ.get("MCP_URL", "")
APIM_GATEWAY_URL        = os.environ.get("APIM_GATEWAY_URL", "")
APIM_SUBSCRIPTION_KEY   = os.environ.get("APIM_SUBSCRIPTION_KEY", "")  # secret!
OPENAI_API_VERSION      = os.environ.get("OPENAI_API_VERSION", "2024-11-01-preview")
OPENAI_DEPLOYMENT_NAME  = os.environ.get("OPENAI_DEPLOYMENT_NAME", "gpt-4o")
ACA_URL                 = f"https://{os.environ.get('CONTAINER_APP_NAME', '')}.{os.environ.get('CONTAINER_APP_ENV_DNS_SUFFIX', '')}"
A2A_URL                 = os.environ.get("A2A_URL", ACA_URL)


def build_app(
    *,
    host: str = "localhost",
    port: int = 10020,
) -> Starlette:
    """
    Assemble and return the fully-wired Starlette ASGI application.

    This function:
      • creates the Semantic Kernel agent
      • wraps it in an A2A executor
      • registers startup/shutdown hooks so the SSE socket is opened/closed
      • builds the A2A Starlette application and returns it
    """

    # -------- 1. Create the naked SemanticKernelAgent -----------------
    agent = AutoGenAgent(
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

    # -------- 2. Wrap it in the A2A executor --------------------------
    sk_agent_exec = A2ALabAgentExecutor(agent=agent)

    # -------- 3. Wire the executor into the default request handler ---
    httpx_client   = httpx.AsyncClient()
    request_handler = DefaultRequestHandler(
        agent_executor = sk_agent_exec,
        task_store     = InMemoryTaskStore(),
        push_notifier  = InMemoryPushNotifier(httpx_client),
    )

    # -------- 4. Build the A2A server via Starlette -------------------
    server = A2AStarletteApplication(
        agent_card   = _get_agent_card(A2A_URL),
        http_handler = request_handler,
    )
    app: Starlette = server.build()

    # -------- 5. Register lifecycle hooks to open/close the agent -----
    @app.on_event("startup")
    async def _startup() -> None:
        log.info("Opening SemanticKernelAgent Streamable connection …")
        await agent.__aenter__()          # opens MCPSsePlugin
        # NB: if you decide to make the *executor* the context
        # manager (Option 2), just call `await sk_agent_exec.__aenter__()`

    @app.on_event("shutdown")
    async def _shutdown() -> None:
        log.info("Closing SemanticKernelAgent Streamable connection …")
        await agent.__aexit__(None, None, None)
        await httpx_client.aclose()

    return app


# ========== Helper: build the agent-card sent to A2A clients ===========
def _get_agent_card(host_url: str) -> AgentCard:
    capabilities = AgentCapabilities(streaming=True)

    skill = AgentSkill(
        id=f'{TITLE}_forecast_autogen',
        name=f'Autogen {TITLE} forecasting agent',
        description=f'Answers questions about the {TITLE} using the tools provided',
        tags=[f'{TITLE}', 'autogen'],
        examples=[
            "What's the weather like in Cairo?",
            "Who's on call today?",
            "What's the capital of Sweden?",
        ],
    )

    return AgentCard(
        name=f'SK {TITLE} Agent',
        description=f'Autogen-powered {TITLE} agent',
        url=f'{host_url}',
        version='1.0.0',
        defaultInputModes=['text'],
        defaultOutputModes=['text'],
        capabilities=capabilities,
        skills=[skill],
    )

import uvicorn

app = build_app()                  # Starlette ASGI application

if __name__ == "__main__":           # Only when you run “python a2a_sk_server.py”
    uvicorn.run(app, host="0.0.0.0", port=10020)