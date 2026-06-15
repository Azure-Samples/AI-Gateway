FROM python:3.12-slim

# Install uv (https://docs.astral.sh/uv/)
COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /uvx /usr/local/bin/

WORKDIR /usr/src/app

# Copy pyproject.toml first for better build caching
COPY pyproject.toml ./

RUN uv pip install --system --no-cache -r pyproject.toml

COPY . .

EXPOSE 5000

ENV FLASK_APP=app.py
ENV HF_HOME=/model_cache

CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
