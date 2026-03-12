import uuid
from azure.identity import DefaultAzureCredential
from azure.mgmt.apimanagement import ApiManagementClient
from azure.mgmt.apimanagement.models import (
    AuthorizationContract,
    AuthorizationAccessPolicyContract,
    AuthorizationLoginRequestContract,
)


class CredentialManagerClient:
    """Manages OAuth credentials using Azure API Management authorization providers."""

    def __init__(
        self,
        tenant_id: str,
        subscription_id: str,
        resource_group_name: str,
        service_name: str,
        apim_identity_object_id: str,
        post_login_redirect_url: str,
        authorization_type: str = "OAuth2",
        oauth2_grant_type: str = "AuthorizationCode",
    ):
        self.tenant_id = tenant_id
        self.subscription_id = subscription_id
        self.resource_group_name = resource_group_name
        self.service_name = service_name
        self.apim_identity_object_id = apim_identity_object_id
        self.post_login_redirect_url = post_login_redirect_url
        self.authorization_type = authorization_type
        self.oauth2_grant_type = oauth2_grant_type
        self._client = ApiManagementClient(
            credential=DefaultAzureCredential(),
            subscription_id=subscription_id,
        )

    def is_authorized(self, authorization_id: str) -> bool:
        """Check if the connection is already authorized.

        Args:
            authorization_id: The authorization identifier.

        Returns:
            True if the authorization status is 'Connected', False otherwise.
        """
        return self._get_authorization_status(authorization_id) == "Connected"

    def _get_authorization_status(self, authorization_provider_id: str, authorization_id: str) -> str | None:
        """Get the current authorization status for a connection.

        Args:
            authorization_provider_id: The authorization provider identifier.
            authorization_id: The authorization identifier.

        Returns:
            The status string ('Connected', 'Error', etc.) or None if not found.
        """
        try:
            response = self._client.authorization.get(
                resource_group_name=self.resource_group_name,
                service_name=self.service_name,
                authorization_provider_id=authorization_provider_id,
                authorization_id=authorization_id,
            )
            return response.status
        except Exception:
            return None

    def get_login_url(self, authorization_provider_id: str, authorization_id: str) -> str:
        """Create an authorization and return the login URL for the user.

        If the connection is already authorized, returns a message indicating so.
        If the authorization already exists (e.g. login pending), skips creation
        and returns the login link directly to avoid duplicate access policy errors.

        Args:
            authorization_provider_id: The authorization provider identifier.
            authorization_id: The authorization identifier.

        Returns:
            The login URL string, or a message if already authorized.
        """
        status = self._get_authorization_status(authorization_provider_id,  authorization_id)

        if status == "Connected":
            return "Connection already authorized."

        # Only create authorization and access policy if no authorization exists yet
        if status is None:
            # Create authorization
            self._client.authorization.create_or_update(
                resource_group_name=self.resource_group_name,
                service_name=self.service_name,
                authorization_provider_id=authorization_provider_id,
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
                authorization_provider_id=authorization_provider_id,
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
            authorization_provider_id=authorization_provider_id,
            authorization_id=authorization_id,
            parameters=AuthorizationLoginRequestContract(
                post_login_redirect_url=self.post_login_redirect_url,
            ),
        )

        return response.login_link

    def delete_authorization(self, authorization_provider_id: str, authorization_id: str) -> None:
        """Delete the authorization for a connection (cleanup).

        Args:
            authorization_provider_id: The authorization provider identifier.
            authorization_id: The authorization identifier.
        """
        try:
            self._client.authorization.delete(
                resource_group_name=self.resource_group_name,
                service_name=self.service_name,
                authorization_provider_id=authorization_provider_id,
                authorization_id=authorization_id,
                if_match="*",
            )
        except Exception:
            pass
