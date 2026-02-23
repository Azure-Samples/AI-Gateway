import httpx
import re
import os
from fastmcp import FastMCP, Context
from credential_manager import CredentialManager

APIM_GATEWAY_URL = str(os.getenv("APIM_GATEWAY_URL"))

mcp = FastMCP("Confluence")

credential_manager = CredentialManager(
    tenant_id=str(os.getenv("AZURE_TENANT_ID")),
    subscription_id=str(os.getenv("SUBSCRIPTION_ID")),
    resource_group_name=str(os.getenv("RESOURCE_GROUP_NAME")),
    service_name=str(os.getenv("APIM_SERVICE_NAME")),
    apim_identity_object_id=str(os.getenv("APIM_IDENTITY_OBJECT_ID")),
    post_login_redirect_url=str(os.getenv("POST_LOGIN_REDIRECT_URL")),
    authorization_provider_id=str(os.getenv("AUTHORIZATION_PROVIDER_ID")),
)

DEFAULT_LIMIT = 25


def _get_session_id(ctx: Context) -> str:
    """Extract the session id from the MCP context."""
    return str(id(ctx.session))


def _get_confluence_headers(session_id: str) -> dict:
    """Build headers for Confluence API calls via APIM."""
    authorization_id = credential_manager._get_authorization_id(session_id)
    return {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "authorizationId": authorization_id,
        "providerId": credential_manager.authorization_provider_id,
    }


async def _ensure_authorized(session_id: str) -> str | None:
    """Check authorization and return login URL if not yet authorized."""
    if not credential_manager.is_authorized(session_id):
        login_url = credential_manager.get_login_url(session_id)
        return f"Please authorize by opening this link: {login_url}"
    return None


def _strip_html(html: str) -> str:
    """Remove HTML tags and collapse whitespace."""
    text = re.sub(r"<[^>]+>", " ", html)
    return re.sub(r"\s+", " ", text).strip()


def _format_page(page: dict, include_body: bool = False) -> str:
    """Format a Confluence page into a readable string."""
    parts: list[str] = []
    parts.append(f"Title: {page.get('title', 'Untitled')}")
    parts.append(f"Page ID: {page.get('id', '')}")
    parts.append(f"Status: {page.get('status', '')}")

    space = page.get("space", {})
    if space:
        parts.append(f"Space: {space.get('name', '')} ({space.get('key', '')})")

    version = page.get("version", {})
    if version:
        parts.append(f"Version: {version.get('number', '')}")
        who = version.get("by", {})
        if who:
            parts.append(f"Last modified by: {who.get('displayName', '')}")

    links = page.get("_links", {})
    webui = links.get("webui", "")
    base = links.get("base", "")
    if webui:
        parts.append(f"URL: {base}{webui}")

    if include_body:
        body = page.get("body", {})
        storage = body.get("storage", {}) or body.get("view", {})
        content = storage.get("value", "")
        if content:
            parts.append(f"\nContent:\n{_strip_html(content)}")

    return "\n".join(parts)


@mcp.tool()
async def search_content(ctx: Context, query: str, limit: int = DEFAULT_LIMIT) -> str:
    """Search for content in Confluence using CQL (Confluence Query Language).

    Args:
        query: A CQL query string. Examples:
            - 'type=page AND text~"release notes"'
            - 'space=ENG AND title~"architecture"'
            - 'label=important AND type=page'
        limit: Maximum number of results to return (default 25, max 100).

    Returns:
        A list of matching pages with titles, IDs, and URLs,
        or a message with the login URL if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_confluence_headers(session_id)
    print(f"Searching Confluence: '{query}' SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.get(
        f"{APIM_GATEWAY_URL}/wiki/rest/api/content/search",
        headers=headers,
        params={"cql": query, "limit": min(limit, 100), "expand": "space,version"},
    )
    if response.status_code != 200:
        return f"Search failed. Status code: {response.status_code}, Response: {response.text}"

    data = response.json()
    results = data.get("results", [])
    if not results:
        return "No results found."

    parts = [f"Found {len(results)} result(s):\n"]
    for page in results:
        parts.append(_format_page(page))
        parts.append("---")

    return "\n".join(parts)


@mcp.tool()
async def get_page(ctx: Context, page_id: str) -> str:
    """Get a Confluence page by its ID, including the full body content.

    Args:
        page_id: The numeric ID of the Confluence page.

    Returns:
        The page title, metadata, and body content,
        or a message with the login URL if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_confluence_headers(session_id)
    print(f"Getting page {page_id}... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.get(
        f"{APIM_GATEWAY_URL}/wiki/rest/api/content/{page_id}",
        headers=headers,
        params={"expand": "body.storage,space,version"},
    )
    if response.status_code != 200:
        return f"Unable to get page. Status code: {response.status_code}, Response: {response.text}"

    return _format_page(response.json(), include_body=True)


@mcp.tool()
async def get_spaces(ctx: Context, limit: int = DEFAULT_LIMIT) -> str:
    """List available Confluence spaces.

    Args:
        limit: Maximum number of spaces to return (default 25, max 100).

    Returns:
        A list of spaces with keys and names,
        or a message with the login URL if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_confluence_headers(session_id)
    print(f"Getting spaces... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.get(
        f"{APIM_GATEWAY_URL}/wiki/rest/api/space",
        headers=headers,
        params={"limit": min(limit, 100), "expand": "description.plain"},
    )
    if response.status_code != 200:
        return f"Unable to get spaces. Status code: {response.status_code}, Response: {response.text}"

    data = response.json()
    results = data.get("results", [])
    if not results:
        return "No spaces found."

    parts = [f"Found {len(results)} space(s):\n"]
    for space in results:
        name = space.get("name", "")
        key = space.get("key", "")
        desc = space.get("description", {}).get("plain", {}).get("value", "")
        line = f"- {name} (key: {key})"
        if desc:
            line += f" — {desc}"
        parts.append(line)

    return "\n".join(parts)


@mcp.tool()
async def get_page_children(ctx: Context, page_id: str, limit: int = DEFAULT_LIMIT) -> str:
    """Get child pages of a Confluence page.

    Args:
        page_id: The numeric ID of the parent page.
        limit: Maximum number of children to return (default 25, max 100).

    Returns:
        A list of child pages with titles and IDs,
        or a message with the login URL if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_confluence_headers(session_id)
    print(f"Getting children of page {page_id}... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.get(
        f"{APIM_GATEWAY_URL}/wiki/rest/api/content/{page_id}/child/page",
        headers=headers,
        params={"limit": min(limit, 100), "expand": "version"},
    )
    if response.status_code != 200:
        return f"Unable to get child pages. Status code: {response.status_code}, Response: {response.text}"

    data = response.json()
    results = data.get("results", [])
    if not results:
        return "No child pages found."

    parts = [f"Found {len(results)} child page(s):\n"]
    for page in results:
        parts.append(_format_page(page))
        parts.append("---")

    return "\n".join(parts)


@mcp.tool()
async def create_page(
    ctx: Context, space_key: str, title: str, body: str, parent_id: str | None = None
) -> str:
    """Create a new page in a Confluence space.

    Args:
        space_key: The key of the space to create the page in (e.g. "ENG").
        title: The title of the new page.
        body: The page body content in Confluence storage format (XHTML).
            Simple HTML like '<p>Hello</p>' works.
        parent_id: Optional ID of a parent page to nest under.

    Returns:
        The created page details, or a message with the login URL
        if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_confluence_headers(session_id)
    print(f"Creating page '{title}' in space {space_key}... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    payload: dict = {
        "type": "page",
        "title": title,
        "space": {"key": space_key},
        "body": {
            "storage": {
                "value": body,
                "representation": "storage",
            }
        },
    }

    if parent_id:
        payload["ancestors"] = [{"id": parent_id}]

    response = httpx.post(
        f"{APIM_GATEWAY_URL}/wiki/rest/api/content",
        headers=headers,
        json=payload,
    )
    if response.status_code not in (200, 201):
        return f"Unable to create page. Status code: {response.status_code}, Response: {response.text}"

    return f"Page created successfully.\n\n{_format_page(response.json())}"


@mcp.tool()
async def add_comment(ctx: Context, page_id: str, comment_body: str) -> str:
    """Add a comment to a Confluence page.

    Args:
        page_id: The numeric ID of the page to comment on.
        comment_body: The comment content in Confluence storage format (XHTML).

    Returns:
        Confirmation of the created comment, or a message with the login URL
        if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_confluence_headers(session_id)
    print(f"Adding comment to page {page_id}... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    payload = {
        "type": "comment",
        "container": {"id": page_id, "type": "page"},
        "body": {
            "storage": {
                "value": comment_body,
                "representation": "storage",
            }
        },
    }

    response = httpx.post(
        f"{APIM_GATEWAY_URL}/wiki/rest/api/content",
        headers=headers,
        json=payload,
    )
    if response.status_code not in (200, 201):
        return f"Unable to add comment. Status code: {response.status_code}, Response: {response.text}"

    data = response.json()
    return f"Comment added successfully. Comment ID: {data.get('id', '')}"


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=f"Run {mcp.name} MCP Streamable-HTTP server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    args = parser.parse_args()
    mcp.run(transport="http", path=f"/mcp", port=args.port, host=args.host)
