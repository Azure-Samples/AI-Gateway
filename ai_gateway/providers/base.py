from abc import ABC, abstractmethod

class LLMProvider(ABC):
    """
    Abstract Base Class for all LLM providers.
    It defines the interface that all concrete provider implementations must follow.
    """

    @abstractmethod
    def chat_completion(self, payload: dict) -> dict:
        """
        Sends a chat completion request to the LLM provider.

        Args:
            payload: The request payload, typically including messages, model, etc.

        Returns:
            The response from the provider as a dictionary.
        """
        pass
