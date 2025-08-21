import pytest
from fastapi.testclient import TestClient
from ai_gateway.main import app

client = TestClient(app)

def test_read_root():
    """
    Tests if the root endpoint returns a 200 OK status and the correct message.
    """
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Welcome to the AI Gateway"}

def test_chat_completion_success(mocker):
    """
    Tests a successful call to the /v1/chat/completions endpoint.
    It mocks the OpenAIProvider to avoid making real API calls.
    """
    # Mock the response from the provider's method
    mock_response = {"choices": [{"message": {"content": "mock response"}}]}

    # Mock the entire OpenAIProvider class where it is used in the chat route
    mock_provider_class = mocker.patch('ai_gateway.routes.chat.OpenAIProvider')

    # Configure the instance that will be created inside the route
    mock_provider_instance = mock_provider_class.return_value
    mock_provider_instance.chat_completion.return_value = mock_response

    request_payload = {
        "model": "gpt-3.5-turbo",
        "messages": [{"role": "user", "content": "Hello!"}]
    }

    response = client.post("/v1/chat/completions", json=request_payload)

    assert response.status_code == 200
    assert response.json() == mock_response
    # Check if the provider was instantiated and the method was called
    mock_provider_class.assert_called_once()
    mock_provider_instance.chat_completion.assert_called_once_with(payload=request_payload)


def test_chat_completion_provider_error(mocker):
    """
    Tests how the endpoint handles an error from the LLM provider.
    """
    # Mock the entire OpenAIProvider class to raise an error on method call
    error_message = "OpenAI API request failed with status 401"
    mock_provider_class = mocker.patch('ai_gateway.routes.chat.OpenAIProvider')
    mock_provider_instance = mock_provider_class.return_value
    mock_provider_instance.chat_completion.side_effect = ValueError(error_message)

    request_payload = {
        "model": "gpt-3.5-turbo",
        "messages": [{"role": "user", "content": "Hello!"}]
    }

    response = client.post("/v1/chat/completions", json=request_payload)

    assert response.status_code == 500
    assert response.json() == {"detail": error_message}
