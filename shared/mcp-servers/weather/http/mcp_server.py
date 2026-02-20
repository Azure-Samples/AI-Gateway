import random
import httpx
import os
from fastmcp import FastMCP, Context

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

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=f"Run {mcp.name} MCP Streamable-HTTP server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    args = parser.parse_args()
    mcp.run(transport="http", path=f"/mcp", port=args.port, host=args.host)
