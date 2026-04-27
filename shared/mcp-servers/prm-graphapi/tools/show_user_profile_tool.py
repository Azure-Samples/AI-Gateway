"""MCP tool for retrieving the current user's profile information from Microsoft Graph."""

import json
import logging
import hashlib
import base64
import secrets
from typing import Optional
from urllib.parse import quote

from starlette.requests import Request
from azure.core.exceptions import ClientAuthenticationError

from config.azure_ad_options import AzureAdOptions
from utilities.graph_client_helper import GraphClientHelper


logger = logging.getLogger(__name__)


class ShowUserProfileTool:
    """MCP tool for retrieving the current user's profile information from Microsoft Graph."""
    
    def __init__(self, azure_ad_options: AzureAdOptions):
        """Initialize the ShowUserProfileTool.
        
        Args:
            azure_ad_options: Azure AD configuration options.
        """
        self.azure_ad_options = azure_ad_options
    
    async def show_user_profile(self, request: Request) -> str:
        """Retrieves and displays the current user's profile information from Microsoft Graph.
        
        Args:
            request: The Starlette request object containing authorization header.
            
        Returns:
            A JSON string representation of the user's profile information or error.
        """
        # Extract authorization header
        auth_header = request.headers.get("Authorization")
        
        if not auth_header:
            logger.warning("Authorization header not found in request")
            return self._create_error_response("Authorization header not found in request")
        
        # Extract Bearer token
        if not auth_header.lower().startswith("bearer "):
            logger.warning("Authorization header does not contain a Bearer token")
            return self._create_error_response("Authorization header must contain a Bearer token")
        
        access_token = auth_header[7:].strip()  # Remove "Bearer " prefix
        
        if not access_token:
            logger.warning("Bearer token is empty in Authorization header")
            return self._create_error_response("Bearer token is empty in Authorization header")
        
        logger.debug("Access token found in Authorization header")
        
        try:
            # Create Graph client and get user profile
            graph_client = GraphClientHelper.create_graph_client(
                access_token, 
                self.azure_ad_options
            )
            
            user = await graph_client.me.get()
            
            if not user:
                logger.warning("User profile not found in Microsoft Graph API response")
                return self._create_error_response("User profile not found")
            
            # Build user profile response
            user_profile = {
                "displayName": user.display_name,
                "email": user.mail or user.user_principal_name,
                "id": user.id,
                "jobTitle": user.job_title,
                "department": user.department,
                "officeLocation": user.office_location
            }
            
            return json.dumps(user_profile, indent=2)
            
        except ClientAuthenticationError as ex:
            # Check if this is a consent-required error
            if self._is_consent_required_error(ex):
                login_url = self._generate_login_url(request)
                consent_response = {
                    "error": "User consent required",
                    "message": "Please provide the following URL to user and ask them to login in order to call Microsoft Graph API",
                    "loginUrl": login_url
                }
                return json.dumps(consent_response, indent=2)
            
            logger.error(f"Authentication failed while retrieving user profile: {ex}")
            return self._create_error_response(f"Authentication failed: {str(ex)}")
            
        except Exception as ex:
            logger.error(f"Unexpected error occurred while retrieving user profile: {ex}")
            return self._create_error_response(f"An unexpected error occurred: {str(ex)}")
    
    def _is_consent_required_error(self, ex: Exception) -> bool:
        """Check if the exception indicates user consent is required.
        
        Args:
            ex: The exception to check.
            
        Returns:
            True if consent is required, False otherwise.
        """
        # Check for MSAL claims challenge exception
        error_msg = str(ex).lower()
        return "invalid_grant" in error_msg or "consent" in error_msg
    
    def _generate_login_url(self, request: Request) -> str:
        """Generate a login URL for user consent.
        
        Args:
            request: The Starlette request object.
            
        Returns:
            The login URL string.
        """
        host = request.url.hostname
        port = request.url.port
        scheme = request.url.scheme
        
        # Build callback URL
        if port and port not in (80, 443):
            host_with_port = f"{host}:{port}"
        else:
            host_with_port = host
            
        callback_url = f"https://{host_with_port}/auth/callback"
        
        # Generate PKCE parameters
        code_verifier = self._generate_code_verifier()
        code_challenge = self._generate_code_challenge(code_verifier)
        
        scopes = "User.Read"  # Microsoft Graph scope
        
        login_url = (
            f"https://login.microsoftonline.com/{self.azure_ad_options.tenant_id}/oauth2/v2.0/authorize?"
            f"client_id={self.azure_ad_options.client_id}&"
            f"response_type=code&"
            f"redirect_uri={quote(callback_url)}&"
            f"response_mode=query&"
            f"scope={quote(scopes)}&"
            f"state=consent_required&"
            f"code_challenge={quote(code_challenge)}&"
            f"code_challenge_method=S256"
        )
        
        return login_url
    
    @staticmethod
    def _generate_code_verifier() -> str:
        """Generate a PKCE code verifier.
        
        Returns:
            A random code verifier string.
        """
        # Code verifier should be 43-128 characters long
        return base64.urlsafe_b64encode(secrets.token_bytes(96)).decode('utf-8').rstrip('=')
    
    @staticmethod
    def _generate_code_challenge(code_verifier: str) -> str:
        """Generate a PKCE code challenge from a code verifier.
        
        Args:
            code_verifier: The code verifier string.
            
        Returns:
            The code challenge string.
        """
        digest = hashlib.sha256(code_verifier.encode('utf-8')).digest()
        return base64.urlsafe_b64encode(digest).decode('utf-8').rstrip('=')
    
    @staticmethod
    def _create_error_response(message: str) -> str:
        """Create a JSON error response.
        
        Args:
            message: The error message.
            
        Returns:
            A JSON string containing the error.
        """
        error_response = {"error": message}
        return json.dumps(error_response, indent=2)
