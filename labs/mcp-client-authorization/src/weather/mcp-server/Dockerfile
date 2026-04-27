FROM python:3.13-slim

WORKDIR /app

# Copy the requirements.txt file into the container
COPY requirements.txt .

# Install the latest FastMCP and dependencies
RUN pip install --no-cache-dir --upgrade -r requirements.txt

# Copy the MCP server code
COPY . .

# Expose the default MCP server port
EXPOSE 8080

# Run the MCP server using Python directly, binding to all interfaces
CMD ["python", "mcp-server.py", "--host", "0.0.0.0", "--port", "8080"]
