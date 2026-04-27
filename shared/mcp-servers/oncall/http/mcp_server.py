import random
import httpx
import os
from fastmcp import FastMCP, Context

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

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=f"Run {mcp.name} MCP Streamable-HTTP server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    args = parser.parse_args()
    mcp.run(transport="http", path=f"/mcp", port=args.port, host=args.host)
