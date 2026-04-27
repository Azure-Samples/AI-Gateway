"""Weather tools for MCP Streamable HTTP server"""

import argparse, random
from fastmcp import FastMCP

mcp = FastMCP(name="weather", instructions="""
        This server provides weather info.
        Call get_cities() to get the list of cities.
        Call get_weather(city) to get the weather for a specific city.
    """,)

@mcp.tool()
async def get_cities(country: str) -> list[str]:
    """Get list of cities for a given country.

    Returns:
        List of cities
    """
    cities_by_country = {
        "usa": ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix"],
        "canada": ["Toronto", "Vancouver", "Montreal", "Calgary", "Ottawa"],
        "uk": ["London", "Manchester", "Birmingham", "Leeds", "Glasgow"],
        "australia": ["Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide"],
        "india": ["Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai"],
        "portugal": ["Lisbon", "Porto", "Braga", "Faro", "Coimbra"]
    }

    cities = cities_by_country.get(country.lower(), [])

    return cities

@mcp.tool()
async def get_weather(city: str) -> str:
    """Get weather information for a given city.

    Returns:
        Weather information
    """

    weather_conditions = ["Sunny", "Cloudy", "Rainy", "Snowy", "Windy"]
    temperature = random.uniform(-10, 35)  # Random temperature between -10 and 35 degrees Celsius
    humidity = random.uniform(20, 100)  # Random humidity between 20% and 100%

    weather_info = {
        "city": city,
        "condition": random.choice(weather_conditions),
        "temperature": round(temperature, 2),
        "humidity": round(humidity, 2),
    }
    return str(weather_info)
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run the Weather MCP server.")
    parser.add_argument("--host", type=str, default="localhost", help="Host to run the server on")
    parser.add_argument("--port", type=int, default=8123, help="Port to run the server on")
    args = parser.parse_args()

    mcp.run(
        transport="http",
        host=args.host,
        port=args.port,
        path="/weather",
        log_level="debug",
    )    
