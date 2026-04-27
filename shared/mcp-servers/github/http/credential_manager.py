import uuid
from azure.identity import DefaultAzureCredential
from azure.mgmt.apimanagement import ApiManagementClient
from azure.mgmt.apimanagement.models import (
    AuthorizationContract,
    AuthorizationAccessPolicyContract,
    AuthorizationLoginRequestContract,
)


class CredentialManager:
    """Manages OAuth credentials for MCP sessions using Azure API Management authorization providers."""

    def __init__(
        self,
        tenant_id: str,
        subscription_id: str,
        resource_group_name: str,
        service_name: str,
        apim_identity_object_id: str,
        post_login_redirect_url: str,
        authorization_provider_id: str,
        authorization_type: str = "OAuth2",
        oauth2_grant_type: str = "AuthorizationCode",
    ):
        self.tenant_id = tenant_id
        self.subscription_id = subscription_id
        self.resource_group_name = resource_group_name
        self.service_name = service_name
        self.apim_identity_object_id = apim_identity_object_id
        self.post_login_redirect_url = post_login_redirect_url
        self.authorization_provider_id = authorization_provider_id
        self.authorization_type = authorization_type
        self.oauth2_grant_type = oauth2_grant_type
        self._client = ApiManagementClient(
            credential=DefaultAzureCredential(),
            subscription_id=subscription_id,
        )

    def _get_authorization_id(self, session_id: str) -> str:
        """Build the authorization id from the provider and session."""
        return f"{self.authorization_provider_id.lower()}-{session_id}"

    def is_authorized(self, session_id: str) -> bool:
        """Check if the session already has a connected authorization.

        Args:
            session_id: The MCP session identifier.

        Returns:
            True if the authorization status is 'Connected', False otherwise.
        """
        return self._get_authorization_status(session_id) == "Connected"

    def _get_authorization_status(self, session_id: str) -> str | None:
        """Get the current authorization status for a session.

        Args:
            session_id: The MCP session identifier.

        Returns:
            The status string ('Connected', 'Error', etc.) or None if not found.
        """
        authorization_id = self._get_authorization_id(session_id)
        try:
            response = self._client.authorization.get(
                resource_group_name=self.resource_group_name,
                service_name=self.service_name,
                authorization_provider_id=self.authorization_provider_id,
                authorization_id=authorization_id,
            )
            return response.status
        except Exception:
            return None

    def get_login_url(self, session_id: str) -> str:
        """Create an authorization and return the login URL for the user.

        If the session is already authorized, returns a message indicating so.
        If the authorization already exists (e.g. login pending), skips creation
        and returns the login link directly to avoid duplicate access policy errors.

        Args:
            session_id: The MCP session identifier.

        Returns:
            The login URL string, or a message if already authorized.
        """
        authorization_id = self._get_authorization_id(session_id)

        status = self._get_authorization_status(session_id)

        if status == "Connected":
            return "Connection already authorized."

        # Only create authorization and access policy if no authorization exists yet
        if status is None:
            # Create authorization
            self._client.authorization.create_or_update(
                resource_group_name=self.resource_group_name,
                service_name=self.service_name,
                authorization_provider_id=self.authorization_provider_id,
                authorization_id=authorization_id,
                parameters=AuthorizationContract(
                    authorization_type=self.authorization_type,
                    o_auth2_grant_type=self.oauth2_grant_type,
                ),
            )

            # Create access policy for the APIM managed identity
            self._client.authorization_access_policy.create_or_update(
                resource_group_name=self.resource_group_name,
                service_name=self.service_name,
                authorization_provider_id=self.authorization_provider_id,
                authorization_id=authorization_id,
                authorization_access_policy_id=str(uuid.uuid4())[:33],
                parameters=AuthorizationAccessPolicyContract(
                    tenant_id=self.tenant_id,
                    object_id=self.apim_identity_object_id,
                ),
            )

        # Get login link (works for both new and existing-but-pending authorizations)
        response = self._client.authorization_login_links.post(
            resource_group_name=self.resource_group_name,
            service_name=self.service_name,
            authorization_provider_id=self.authorization_provider_id,
            authorization_id=authorization_id,
            parameters=AuthorizationLoginRequestContract(
                post_login_redirect_url=self.post_login_redirect_url,
            ),
        )

        return response.login_link

    def delete_authorization(self, session_id: str) -> None:
        """Delete the authorization for a session (cleanup).

        Args:
            session_id: The MCP session identifier.
        """
        authorization_id = self._get_authorization_id(session_id)
        try:
            self._client.authorization.delete(
                resource_group_name=self.resource_group_name,
                service_name=self.service_name,
                authorization_provider_id=self.authorization_provider_id,
                authorization_id=authorization_id,
                if_match="*",
            )
        except Exception:
            pass
