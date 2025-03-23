from typing import Any
import httpx, os, uuid
from mcp.server.fastmcp import FastMCP, Context
from starlette.applications import Starlette
from mcp.server.sse import SseServerTransport
from starlette.requests import Request
from starlette.routing import Mount, Route
from mcp.server import Server
import uvicorn
from azure.identity import DefaultAzureCredential
from azure.mgmt.apimanagement import ApiManagementClient
from azure.mgmt.apimanagement.models import AuthorizationContract, AuthorizationAccessPolicyContract, AuthorizationLoginRequestContract


# Initialize FastMCP server for Github API
mcp = FastMCP("Time")

# Environment variables
APIM_GATEWAY_URL = str(os.getenv("APIM_GATEWAY_URL"))
TIME_API_BASE = "http://worldtimeapi.org/api"

async def make_time_request(url: str) -> dict[str, Any] | None:
    """Make a request to the World Time API."""
    headers = {
        "Accept": "application/json"
    }
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, headers=headers, timeout=30.0)
            response.raise_for_status()
            return response.json()
        except Exception:
            return None

@mcp.tool()
async def get_time(timezone: str) -> str:
    """Get current time for a given timezone."""
    url = f"{APIM_GATEWAY_URL}/timezone/{timezone}"
    data = await make_time_request(url)
    if not data:
        return "Unable to fetch time for this timezone."
    current_time = data.get("datetime")
    if not current_time:
        return "No valid time found."
    return f"Current time in {timezone} is {current_time}"

def create_starlette_app(mcp_server: Server, *, debug: bool = False) -> Starlette:
    """Create a Starlette application that can server the provied mcp server with SSE."""
    sse = SseServerTransport("/time/messages/")

    async def handle_sse(request: Request) -> None:
        print(f"handling sse")

        async with sse.connect_sse(
                request.scope,
                request.receive,
                request._send,  
        ) as (read_stream, write_stream):
            await mcp_server.run(
                read_stream,
                write_stream,
                mcp_server.create_initialization_options(),
            )

    return Starlette(
        debug=debug,
        routes=[
            Route("/time/sse", endpoint=handle_sse),
            Mount("/time/messages/", app=sse.handle_post_message),
        ],
    )


mcp_server = mcp._mcp_server  

# Bind SSE request handling to MCP server
starlette_app = create_starlette_app(mcp_server, debug=True)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Run MCP SSE-based server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type='int', default=8080, help='Port to listen on')
    args = parser.parse_args()

    uvicorn.run(starlette_app, host=args.host, port=args.port)