# Use Python 3.11 slim image as base
FROM python:3.11-slim

# Install uv (https://docs.astral.sh/uv/)
COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /uvx /usr/local/bin/

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Install system dependencies (if needed for Azure/Graph libraries)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy pyproject.toml first for better caching
COPY pyproject.toml .

# Install Python dependencies via uv
RUN uv pip install --system --no-cache -r pyproject.toml

# Copy application code
COPY config/ ./config/
COPY controllers/ ./controllers/
COPY tools/ ./tools/
COPY utilities/ ./utilities/
COPY main.py .

# Create a non-root user to run the application
RUN useradd -m -u 1000 mcpuser && \
    chown -R mcpuser:mcpuser /app

# Switch to non-root user
USER mcpuser

# Expose the port the app runs on
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()" || exit 1

# Set default environment variables (can be overridden)
ENV HOST=0.0.0.0 \
    PORT=8000 \
    FASTMCP_HOST=0.0.0.0 \
    FASTMCP_PORT=8000

# Run the application
# CMD ["python", "main.py"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
