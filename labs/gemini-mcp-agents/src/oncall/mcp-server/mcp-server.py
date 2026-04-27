from typing import Any
import httpx, os, random
from mcp.server.fastmcp import FastMCP, Context
from starlette.applications import Starlette
from mcp.server.sse import SseServerTransport
from starlette.requests import Request
from starlette.routing import Mount, Route
from mcp.server import Server
import uvicorn

# Initialize FastMCP server for Oncall API
mcp = FastMCP("Oncall")

@mcp.tool()
async def get_oncall_list(ctx: Context) -> str:
    """Get list of people currently on-call with their status and time zone.

    Returns:
        List of on-call personnel with their details
    """
    oncall_list = [
        {"id": 1, "firstName": "Julia", "lastName": "Smith", "alias": "jsmith", "status": "on", "timezone": "PST"},
        {"id": 2, "firstName": "Alex", "lastName": "Johnson", "alias": "ajohnson", "status": "on", "timezone": "EST"},
        {"id": 3, "firstName": "Maria", "lastName": "Garcia", "alias": "mgarcia", "status": "off", "timezone": "CET"},
        {"id": 4, "firstName": "David", "lastName": "Wilson", "alias": "dwilson", "status": "on", "timezone": "CET"},
        {"id": 5, "firstName": "Sarah", "lastName": "Chen", "alias": "schen", "status": "on", "timezone": "CET"},
        {"id": 6, "firstName": "Michael", "lastName": "Brown", "alias": "mbrown", "status": "off", "timezone": "PST"},
        {"id": 7, "firstName": "Emma", "lastName": "Taylor", "alias": "etaylor", "status": "on", "timezone": "PST"}
    ]
    
    return str(oncall_list)

def create_starlette_app(mcp_server: Server, *, debug: bool = False) -> Starlette:
    """Create a Starlette application that can server the provied mcp server with SSE."""
    sse = SseServerTransport("/oncall/messages/")

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
            Route("/oncall/sse", endpoint=handle_sse),
            Mount("/oncall/messages/", app=sse.handle_post_message),
        ],
    )

mcp_server = mcp._mcp_server  

# Bind SSE request handling to MCP server
starlette_app = create_starlette_app(mcp_server, debug=True)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Run MCP SSE-based server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8080, help='Port to listen on')
    args = parser.parse_args()

    uvicorn.run(starlette_app, host=args.host, port=args.port)