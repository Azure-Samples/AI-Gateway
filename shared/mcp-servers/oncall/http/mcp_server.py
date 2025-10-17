import random
import uvicorn

# Support either the standalone 'fastmcp' package or the 'mcp' package layout.
try:
    from fastmcp import FastMCP, Context  # pip install fastmcp
except ModuleNotFoundError:  # fall back to the layout you used originally
    from mcp.server.fastmcp import FastMCP, Context  # pip install mcp

from starlette.applications import Starlette
from starlette.routing import Mount



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

# Expose an ASGI app that speaks Streamable HTTP at /mcp/
mcp_asgi = mcp.http_app()
app = Starlette(
    routes=[Mount("/oncall", app=mcp_asgi)],  # MCP will be at /weather/mcp/
    lifespan=mcp_asgi.lifespan, 
)

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Run MCP Streamable-HTTP server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    args = parser.parse_args()
    uvicorn.run(app, host=args.host, port=args.port)
