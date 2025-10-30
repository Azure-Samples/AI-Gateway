"""Utility class for creating Microsoft Graph clients using On-Behalf-Of (OBO) flow."""

from azure.identity import OnBehalfOfCredential, ManagedIdentityCredential
from azure.core.credentials import AccessToken
from msgraph import GraphServiceClient
from config.azure_ad_options import AzureAdOptions
from typing import Callable
import asyncio


class GraphClientHelper:
    """Utility class for creating Microsoft Graph clients using On-Behalf-Of (OBO) flow."""
    
    @staticmethod
    def create_graph_client(access_token: str, azure_ad_options: AzureAdOptions) -> GraphServiceClient:
        """Creates a GraphServiceClient using On-Behalf-Of authentication flow.
        
        Args:
            access_token: The access token to use for OBO flow.
            azure_ad_options: Azure AD configuration options.
            
        Returns:
            A configured GraphServiceClient instance.
            
        Raises:
            ValueError: If access token is None or empty.
        """
        if not access_token or not access_token.strip():
            raise ValueError("Access token cannot be null or empty.")
        
        credential = GraphClientHelper._create_on_behalf_of_credential(
            access_token, 
            azure_ad_options
        )
        return GraphServiceClient(credentials=credential)
    
    @staticmethod
    def _create_on_behalf_of_credential(
        access_token: str, 
        azure_ad_options: AzureAdOptions
    ) -> OnBehalfOfCredential:
        """Creates an OnBehalfOfCredential for Microsoft Graph authentication.
        
        Args:
            access_token: The access token to use for OBO flow.
            azure_ad_options: Azure AD configuration options.
            
        Returns:
            Configured OnBehalfOfCredential instance.
        """

        managed_identity = ManagedIdentityCredential(
            client_id=azure_ad_options.managed_identity_client_id
        )
        
        def client_assertion_callback() -> str:
            """Callback to get client assertion token from managed identity.
            
            Returns:
                The access token string.
            """
            # Get token for federated credential exchange
            token_result = managed_identity.get_token("api://AzureADTokenExchange")
            return token_result.token
        
        return OnBehalfOfCredential(
            tenant_id=azure_ad_options.tenant_id,
            client_id=azure_ad_options.client_id,
            client_assertion_func=client_assertion_callback,
            user_assertion=access_token
        )
