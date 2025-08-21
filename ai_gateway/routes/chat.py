from fastapi import APIRouter, HTTPException, Body, Request
from ..providers.openai import OpenAIProvider
from ..core.limiter import limiter
from typing import Any

router = APIRouter()

@router.post("/v1/chat/completions")
@limiter.limit("5/minute")
async def chat_completions(
    request: Request, # The limiter needs access to the request object
    request_body: dict = Body(...)
):
    """
    Forwards a chat completion request to the configured LLM provider.
    This endpoint is compatible with the OpenAI chat completions format.
    """
    try:
        # In a more complex scenario, you might have a factory or a registry
        # to select the provider based on the request (e.g., model name).
        provider = OpenAIProvider()
        response = provider.chat_completion(payload=request_body)
        return response
    except ValueError as e:
        # This can be triggered by misconfiguration or API errors from the provider
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        # Catch-all for other unexpected errors
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")
