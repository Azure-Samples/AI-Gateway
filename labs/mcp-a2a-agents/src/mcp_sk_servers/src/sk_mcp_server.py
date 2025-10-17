import asyncio
from semantic_kernel.agents import ChatCompletionAgent
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion
from semantic_kernel.connectors.mcp import MCPStreamableHttpPlugin

import os

TITLE                   = os.environ.get("TITLE", "Weather")
MCP_URL                 = os.environ.get("MCP_URL", "/weather")
apim_resource_gateway_url        = os.environ.get("APIM_GATEWAY_URL", "")
apim_subscription_key   = os.environ.get("APIM_SUBSCRIPTION_KEY", "")  # secret!
inference_api_version      = os.environ.get("OPENAI_API_VERSION", "2025-03-01-preview")
inference_api_path = os.environ.get("INFERENCE_API_PATH", "")
openai_model_name  = os.environ.get("OPENAI_DEPLOYMENT_NAME", "gpt-4o-mini")

### TODO: Integrate in Server lifecycle - current life cycle creates 1 persistent SK Agent, no threads, no fallback
async def _safe_disconnect(plugin: MCPStreamableHttpPlugin) -> None:
    """Handle SK method differences across versions."""
    for method_name in ("disconnect", "close", "aclose"):
        method = getattr(plugin, method_name, None)
        if method:
            maybe_coro = method()
            if asyncio.iscoroutine(maybe_coro):
                await maybe_coro
            return

async def build_agent(mcp_path: str | None = None, title: str | None = None):
    # Connect the agent to Azure OpenAI
    service = AzureChatCompletion(
            endpoint=f"{apim_resource_gateway_url}/{inference_api_path}",
            api_key=apim_subscription_key,
            api_version=inference_api_version,                
            deployment_name=openai_model_name  # Use the first model from the models_config
        )

    # Attach a remote MCP plugin the agent can call during reasoning
    # (e.g., a weather or tools server you already host elsewhere)
    mcp_plugin = MCPStreamableHttpPlugin(
        name=title,
        url=f"{apim_resource_gateway_url}/{mcp_path}",
        description=f"Remote {title} MCP Plugin via HTTP Streamable Transport",
    )

    await mcp_plugin.connect()

    agent = ChatCompletionAgent(
        service=service,
        name=f"{title}Agent",
        instructions=(
            "You are a helpful assistant. "
            f"Use the '{title}' plugin when the user asks about {title.lower()}. "
            "Cite the source if appropriate."
        ),
        plugins=[mcp_plugin],
    )

    return agent

import argparse
import logging
from typing import Any, Literal

from starlette.responses import Response

from semantic_kernel.prompt_template import InputVariable, KernelPromptTemplate, PromptTemplateConfig
from semantic_kernel import Kernel
from semantic_kernel.connectors.ai.open_ai import OpenAIChatCompletion
from semantic_kernel.functions import kernel_function
from semantic_kernel.prompt_template.input_variable import InputVariable
from semantic_kernel.prompt_template.prompt_template_config import PromptTemplateConfig

async def run(transport: Literal["sse", "stdio", "http"] = "stdio", port: int | None = None, mcp_path: str | None = None, title: str | None = None) -> None:
    kernel = await build_agent(mcp_path=mcp_path, title=title)

    @kernel_function()
    async def echo_function(message: str, extra: str = "") -> str:
        """Echo a message as a function"""
        return f"Function echo: {message} {extra}"

    prompt = KernelPromptTemplate(
        prompt_template_config=PromptTemplateConfig(
            name=f"{title}_report_prompt",
            description="This creates the prompts for a full set of reports based on the location given.",
            template="Report in {{$city}}?",
            input_variables=[
                InputVariable(
                    name="city",
                    description=f"The city to get the {title.lower()} report for.",
                    is_required=True,
                    json_schema='{"type": "string"}',
                )
            ],
        )
    )

    mcp_server = kernel.as_mcp_server(server_name=f"{title}_sk_aca", prompts=[prompt])

    if transport == "http" and port is not None:
        import contextlib
        from mcp.server.streamable_http_manager import StreamableHTTPSessionManager
        from mcp.server.fastmcp import FastMCP
        from starlette.types import Receive, Scope, Send
        from starlette.applications import Starlette
        from typing import AsyncIterator
        from starlette.routing import Mount
        import uvicorn

        session_manager = StreamableHTTPSessionManager(
            app=mcp_server,
            event_store=None,
            json_response=True,
            stateless=True,
            )
        async def handle_streamable_http(scope: Scope, receive: Receive, send: Send) -> None:
            await session_manager.handle_request(scope, receive, send)

        @contextlib.asynccontextmanager
        async def lifespan(app: Starlette) -> AsyncIterator[None]:
            """Context manager for session manager."""
            async with session_manager.run():
                try:
                    yield
                finally:
                    print("Application shutting down...")

        import nest_asyncio
        nest_asyncio.apply() 
        
        starlette_app = Starlette(
            debug=True,
                routes=[
                    Mount("/mcp", app=handle_streamable_http),
                ],
                lifespan=lifespan,
            )
        uvicorn.run(starlette_app, host="0.0.0.0", port=port)

    if transport == "sse" and port is not None:
        import uvicorn
        from mcp.server.sse import SseServerTransport
        from starlette.applications import Starlette
        from starlette.routing import Mount, Route

        sse = SseServerTransport("/messages/")

        async def handle_sse(request):
            async with sse.connect_sse(request.scope, request.receive, request._send) as (read_stream, write_stream):
                await mcp_server.run(read_stream, write_stream, mcp_server.create_initialization_options())
            return Response(status_code=204)  # <— important!

        starlette_app = Starlette(
            debug=True,
            routes=[
                Route("/sse", endpoint=handle_sse),
                Mount("/messages/", app=sse.handle_post_message),
            ],
        )
        import nest_asyncio
        nest_asyncio.apply() 

        uvicorn.run(starlette_app, host="0.0.0.0", port=port)  # nosec
        
    elif transport == "stdio":
        import anyio
        from mcp.server.stdio import stdio_server

        async def handle_stdin(stdin: Any | None = None, stdout: Any | None = None) -> None:
            async with stdio_server() as (read_stream, write_stream):
                await mcp_server.run(read_stream, write_stream, mcp_server.create_initialization_options())

        anyio.run(handle_stdin)

def parse_arguments():
    parser = argparse.ArgumentParser(description="Run the Semantic Kernel MCP server.")
    parser.add_argument(
        "--transport",
        type=str,
        choices=["sse", "stdio", "http"],
        default="http",
        help="Transport method to use (default: http).",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=9090,
        help="Port to use for SSE/Streamable HTTP transport (required if transport is 'sse' or 'http').",
    )
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_arguments()
    asyncio.run(run(transport=args.transport, port=args.port, mcp_path=MCP_URL, title=TITLE), debug=True)