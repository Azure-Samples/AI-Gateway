"""Azure AD configuration options."""

from dataclasses import dataclass
from typing import Optional
import os
from dotenv import load_dotenv


@dataclass
class AzureAdOptions:
    """Azure AD configuration options.
    
    Attributes:
        tenant_id: The Azure AD tenant ID.
        client_id: The client ID of the application.
        managed_identity_client_id: The client ID of the managed identity used as federated credential.
    """
    tenant_id: str
    client_id: str
    managed_identity_client_id: str

    @classmethod
    def from_env(cls) -> "AzureAdOptions":
        """Load Azure AD options from environment variables.
        
        Returns:
            AzureAdOptions instance populated from environment variables.
        
        Raises:
            ValueError: If required environment variables are missing.
        """
        # Try to load from .env file
        load_dotenv()
        
        tenant_id = os.getenv("AZURE_TENANT_ID", "")
        client_id = os.getenv("AZURE_CLIENT_ID", "")
        managed_identity_client_id = os.getenv("AZURE_MANAGED_IDENTITY_CLIENT_ID", "")
        
        if not all([tenant_id, client_id, managed_identity_client_id]):
            raise ValueError(
                "Missing required environment variables: "
                "AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_MANAGED_IDENTITY_CLIENT_ID"
            )
        
        return cls(
            tenant_id=tenant_id,
            client_id=client_id,
            managed_identity_client_id=managed_identity_client_id
        )
