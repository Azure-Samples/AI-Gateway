# ────────────────────────────────────────────────────────────────
# Stage 1 – build wheels in a clean layer
# ────────────────────────────────────────────────────────────────
FROM python:3.13-slim AS builder

ARG PIP_NO_CACHE_DIR=off          # build-time arg, overrides if you need
WORKDIR /build

COPY requirements.txt .
RUN pip wheel --wheel-dir /wheels -r requirements.txt

# ────────────────────────────────────────────────────────────────
# Stage 2 – runtime image
# ────────────────────────────────────────────────────────────────
FROM python:3.13-slim

# Copy wheels from the builder and install them
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/*.whl

# Copy the rest of the application code
WORKDIR /app
COPY . /app

# ── Runtime configuration placeholders ─────────────────────────
# These are *defaults only*; ACA will override them at deploy time.
ENV PORT="9090" \
    TITLE="Weather" \
    MCP_URL="" \
    APIM_GATEWAY_URL="" \
    APIM_SUBSCRIPTION_KEY="" \
    OPENAI_API_VERSION="2024-11-01-preview" \
    OPENAI_DEPLOYMENT_NAME="gpt-4o" \
    OPENAI_CLIENT_TYPE="azure" \
    PYTHONUNBUFFERED=1

EXPOSE 9090

# Uvicorn tends to handle reload/signals better than raw “python run_server.py”
CMD ["python", "sk_mcp_server.py", "--transport", "http", "--port", "9090"]
