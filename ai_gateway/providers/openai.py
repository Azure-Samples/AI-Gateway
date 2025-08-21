import requests
from .base import LLMProvider
from ..config import settings

OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"

class OpenAIProvider(LLMProvider):
    """
    Concrete implementation of the LLMProvider for OpenAI's API.
    """

    def __init__(self, api_key: str = settings.OPENAI_API_KEY):
        """
        Initializes the OpenAI provider with an API key.
        """
        if not api_key or api_key == "YOUR_API_KEY_HERE":
            raise ValueError("OpenAI API key is not configured. Please set it in your .env file.")
        self.api_key = api_key

    def chat_completion(self, payload: dict) -> dict:
        """
        Sends a chat completion request to the OpenAI API.

        Args:
            payload: The request payload, including model, messages, etc.

        Returns:
            The JSON response from the OpenAI API as a dictionary.

        Raises:
            requests.exceptions.RequestException: For network-related errors.
            ValueError: If the API returns a non-200 status code.
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        try:
            response = requests.post(OPENAI_API_URL, headers=headers, json=payload)
            response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)
            return response.json()
        except requests.exceptions.HTTPError as http_err:
            # You can add more specific error handling here
            # For now, just re-raise as a ValueError with more context
            raise ValueError(f"OpenAI API request failed with status {response.status_code}: {response.text}") from http_err
        except requests.exceptions.RequestException as req_err:
            # Handle connection errors, timeouts, etc.
            raise ValueError(f"An error occurred while communicating with OpenAI API: {req_err}") from req_err
