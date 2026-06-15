# ────────────────────────────────────────────────────────────────
# uv-based single-stage build (uv is fast enough that wheel-prebuild
# multi-stage is no longer required).
# ────────────────────────────────────────────────────────────────
FROM python:3.13-slim

# Install uv (https://docs.astral.sh/uv/)
COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /uvx /usr/local/bin/

WORKDIR /app

# Copy pyproject.toml first for better build caching
COPY pyproject.toml ./
RUN uv pip install --system --no-cache -r pyproject.toml

# Copy the rest of the application code
COPY . /app

# ── Runtime configuration placeholders ─────────────────────────
# These are *defaults only*; ACA will override them at deploy time.
ENV PORT="9090" \
    TITLE="Weather" \
    MCP_URL="" \
    APIM_GATEWAY_URL="" \
    APIM_SUBSCRIPTION_KEY="" \
    OPENAI_API_VERSION="2024-11-01-preview" \
    OPENAI_DEPLOYMENT_NAME="gpt-4.1-mini" \
    OPENAI_CLIENT_TYPE="azure" \
    PYTHONUNBUFFERED=1

EXPOSE 9090

# Uvicorn tends to handle reload/signals better than raw “python run_server.py”
CMD ["uvicorn", "a2a_server:app", "--host", "0.0.0.0", "--port", "9090"]
