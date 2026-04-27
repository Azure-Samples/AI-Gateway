FROM python:3.13.2-slim

WORKDIR /app

# Copy the requirements.txt file into the container
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["uvicorn", "mcp-server:starlette_app", "--host", "0.0.0.0", "--port", "8080"]
