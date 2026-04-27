import httpx
import os
from fastmcp import FastMCP, Context
from credential_manager import CredentialManager

APIM_GATEWAY_URL = str(os.getenv("APIM_GATEWAY_URL"))

mcp = FastMCP("GitHub")

credential_manager = CredentialManager(
    tenant_id=str(os.getenv("AZURE_TENANT_ID")),
    subscription_id=str(os.getenv("SUBSCRIPTION_ID")),
    resource_group_name=str(os.getenv("RESOURCE_GROUP_NAME")),
    service_name=str(os.getenv("APIM_SERVICE_NAME")),
    apim_identity_object_id=str(os.getenv("APIM_IDENTITY_OBJECT_ID")),
    post_login_redirect_url=str(os.getenv("POST_LOGIN_REDIRECT_URL")),
    authorization_provider_id=str(os.getenv("AUTHORIZATION_PROVIDER_ID")),
)


def _get_session_id(ctx: Context) -> str:
    """Extract the session id from the MCP context."""
    return str(id(ctx.session))


def _get_github_headers(session_id: str) -> dict:
    """Build headers for GitHub API calls via APIM."""
    authorization_id = credential_manager._get_authorization_id(session_id)
    return {
        "Content-Type": "application/json",
        "authorizationId": authorization_id,
        "providerId": credential_manager.authorization_provider_id,
    }


async def _ensure_authorized(session_id: str) -> str | None:
    """Check authorization and return login URL if not yet authorized."""
    if not credential_manager.is_authorized(session_id):
        login_url = credential_manager.get_login_url(session_id)
        return f"Please authorize by opening this link: {login_url}"
    return None


@mcp.tool()
async def get_user(ctx: Context) -> str:
    """Get user associated with GitHub access token.

    Returns:
        GitHub user information if the connection is authorized, otherwise a message with the login URL.
    """
    session_id = _get_session_id(ctx)
    print(f"Getting user info... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.get(
        f"{APIM_GATEWAY_URL}/user",
        headers=_get_github_headers(session_id),
    )
    if response.status_code == 200:
        return f"User: {response.json()}"
    else:
        return f"Unable to get user info. Status code: {response.status_code}, Response: {response.text}"


@mcp.tool()
async def get_issues(ctx: Context, username: str, repo: str) -> str:
    """Get all issues for the specified repository for the authenticated user.

    Args:
        username: The GitHub username
        repo: The repository name

    Returns:
        A list of issues if the connection is authorized, otherwise a message with the login URL.
    """
    session_id = _get_session_id(ctx)
    print(f"Getting the list of issues... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.get(
        f"{APIM_GATEWAY_URL}/repos/{username}/{repo}/issues",
        headers=_get_github_headers(session_id),
    )
    if response.status_code == 200:
        return f"Issues: {response.json()}"
    else:
        return f"Unable to get issues. Status code: {response.status_code}, Response: {response.text}"


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=f"Run {mcp.name} MCP Streamable-HTTP server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    args = parser.parse_args()
    mcp.run(transport="http", path=f"/mcp", port=args.port, host=args.host)
