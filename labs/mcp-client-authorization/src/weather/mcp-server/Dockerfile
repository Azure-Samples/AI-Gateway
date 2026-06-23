FROM python:3.13-slim

# Install uv (https://docs.astral.sh/uv/)
COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /uvx /usr/local/bin/

WORKDIR /app

# Copy pyproject.toml first for better build caching
COPY pyproject.toml ./

# Install the latest FastMCP and dependencies
RUN uv pip install --system --no-cache -r pyproject.toml

# Copy the MCP server code
COPY . .

# Expose the default MCP server port
EXPOSE 8080

# Run the MCP server using Python directly, binding to all interfaces
CMD ["python", "mcp-server.py", "--host", "0.0.0.0", "--port", "8080"]
