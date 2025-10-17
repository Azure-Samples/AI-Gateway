import random
import uvicorn

# Support either the standalone 'fastmcp' package or the 'mcp' package layout.
try:
    from fastmcp import FastMCP, Context  # pip install fastmcp
except ModuleNotFoundError:  # fall back to the layout you used originally
    from mcp.server.fastmcp import FastMCP, Context  # pip install mcp

from starlette.applications import Starlette
from starlette.routing import Mount



mcp = FastMCP("Weather")

@mcp.tool()
async def get_cities(ctx: Context, country: str) -> str:
    """Get list of cities for a given country."""
    cities_by_country = {
        "usa": ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix"],
        "canada": ["Toronto", "Vancouver", "Montreal", "Calgary", "Ottawa"],
        "uk": ["London", "Manchester", "Birmingham", "Leeds", "Glasgow"],
        "australia": ["Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide"],
        "india": ["Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai"],
        "portugal": ["Lisbon", "Porto", "Braga", "Faro", "Coimbra"],
    }
    return str(cities_by_country.get(country.lower(), []))

@mcp.tool()
async def get_weather(ctx: Context, city: str) -> str:
    """Get weather information for a given city."""
    weather_conditions = ["Sunny", "Cloudy", "Rainy", "Snowy", "Windy"]
    temperature = random.uniform(-10, 35)
    humidity = random.uniform(20, 100)
    weather_info = {
        "city": city,
        "condition": random.choice(weather_conditions),
        "temperature": round(temperature, 2),
        "humidity": round(humidity, 2),
    }
    return str(weather_info)

# Expose an ASGI app that speaks Streamable HTTP at /mcp/
mcp_asgi = mcp.http_app()
app = Starlette(
    routes=[Mount("/weather", app=mcp_asgi)],  # MCP will be at /weather/mcp/
    lifespan=mcp_asgi.lifespan, 
)

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Run MCP Streamable-HTTP server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    args = parser.parse_args()
    uvicorn.run(app, host=args.host, port=args.port)
