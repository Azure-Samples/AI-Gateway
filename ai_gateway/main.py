from fastapi import FastAPI, Request
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from .config import settings
from .core.limiter import limiter
from .routes import chat

app = FastAPI(
    title="AI Gateway",
    description="A modular AI Gateway built with FastAPI.",
    version="0.1.0"
)

# Add the slowapi middleware
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.include_router(chat.router)


@app.get("/")
def read_root():
    """
    Root endpoint to check if the API is running.
    """
    return {"message": "Welcome to the AI Gateway"}

# To run this application:
# uvicorn ai_gateway.main:app --reload
