import httpx
import asyncio
import json
import os
from fastmcp import FastMCP, Context
from credential_manager import CredentialManager

APIM_GATEWAY_URL = str(os.getenv("APIM_GATEWAY_URL"))
GENIE_SPACE_ID = str(os.getenv("GENIE_SPACE_ID"))

POLL_INTERVAL_SECONDS = 2
MAX_POLL_ATTEMPTS = 60

COMPLETED_STATUSES = {"COMPLETED"}
FAILED_STATUSES = {"FAILED", "CANCELLED"}

mcp = FastMCP("Databricks-Genie")

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


def _get_databricks_headers(session_id: str) -> dict:
    """Build headers for Databricks API calls via APIM."""
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


def _genie_url(path: str = "") -> str:
    """Build the full Genie API URL for the configured space."""
    return f"{APIM_GATEWAY_URL}/api/2.0/genie/spaces/{GENIE_SPACE_ID}{path}"


async def _poll_message(
    conversation_id: str, message_id: str, headers: dict
) -> dict:
    """Poll a Genie message until it reaches a terminal status.

    Args:
        conversation_id: The Genie conversation ID.
        message_id: The Genie message ID.
        headers: Request headers for authentication.

    Returns:
        The final message response as a dictionary.

    Raises:
        TimeoutError: If the message does not complete within the polling limit.
        RuntimeError: If the message reaches a failed status.
    """
    url = _genie_url(f"/conversations/{conversation_id}/messages/{message_id}")

    for _ in range(MAX_POLL_ATTEMPTS):
        response = httpx.get(url, headers=headers)
        response.raise_for_status()
        data = response.json()
        status = data.get("status", "")

        if status in COMPLETED_STATUSES:
            return data
        if status in FAILED_STATUSES:
            error = data.get("error", "Unknown error")
            raise RuntimeError(f"Genie message failed with status '{status}': {error}")

        await asyncio.sleep(POLL_INTERVAL_SECONDS)

    raise TimeoutError(
        f"Genie message {message_id} did not complete within {MAX_POLL_ATTEMPTS * POLL_INTERVAL_SECONDS}s"
    )


def _format_message_response(data: dict) -> str:
    """Format a Genie message response into a readable string."""
    parts: list[str] = []

    conversation_id = data.get("conversation_id", "")
    message_id = data.get("id", "")
    status = data.get("status", "")
    parts.append(f"Status: {status}")
    parts.append(f"Conversation ID: {conversation_id}")
    parts.append(f"Message ID: {message_id}")

    # Extract attachments (contains SQL queries, descriptions, etc.)
    for attachment in data.get("attachments", []):
        if "text" in attachment:
            text_content = attachment["text"].get("content", "")
            if text_content:
                parts.append(f"\n{text_content}")

        if "query" in attachment:
            query = attachment["query"]
            description = query.get("description", "")
            sql = query.get("query", "")
            if description:
                parts.append(f"\nDescription: {description}")
            if sql:
                parts.append(f"\nSQL Query:\n```sql\n{sql}\n```")

    return "\n".join(parts)


@mcp.tool()
async def ask_genie(ctx: Context, question: str, conversation_id: str | None = None) -> str:
    """Ask a natural language question to the Databricks Genie space.

    Starts a new conversation or continues an existing one. Polls until
    Genie finishes processing and returns the response.

    Args:
        question: The natural language question to ask about your data.
        conversation_id: Optional ID of an existing conversation to continue.
            Omit to start a new conversation.

    Returns:
        The Genie response including any generated SQL query and description,
        or a message with the login URL if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_databricks_headers(session_id)
    print(f"Asking Genie: '{question}' SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    try:
        if conversation_id:
            # Continue existing conversation
            url = _genie_url(f"/conversations/{conversation_id}/messages")
        else:
            # Start new conversation
            url = _genie_url("/start-conversation")

        response = httpx.post(url, headers=headers, json={"content": question})
        if response.status_code not in (200, 201):
            return (
                f"Unable to send message to Genie. "
                f"Status code: {response.status_code}, Response: {response.text}"
            )

        data = response.json()
        conv_id = data.get("conversation_id", conversation_id or "")
        msg_id = data.get("message_id") or data.get("id", "")

        # Poll until the message is complete
        result = await _poll_message(conv_id, msg_id, headers)
        return _format_message_response(result)

    except (TimeoutError, RuntimeError) as exc:
        return f"Error: {exc}"
    except httpx.HTTPStatusError as exc:
        return f"HTTP error: {exc.response.status_code} - {exc.response.text}"


@mcp.tool()
async def get_query_result(ctx: Context, conversation_id: str, message_id: str) -> str:
    """Get the SQL query execution result from a Genie conversation message.

    Use this after ask_genie returns a response containing a SQL query, to
    retrieve the actual data rows produced by that query.

    Args:
        conversation_id: The conversation ID returned by ask_genie.
        message_id: The message ID returned by ask_genie.

    Returns:
        The query result as a formatted table, or a message with the login URL
        if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_databricks_headers(session_id)
    print(f"Getting query result for message {message_id}... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    try:
        url = _genie_url(
            f"/conversations/{conversation_id}/messages/{message_id}/query-result"
        )
        response = httpx.get(url, headers=headers)
        if response.status_code != 200:
            return (
                f"Unable to get query result. "
                f"Status code: {response.status_code}, Response: {response.text}"
            )

        data = response.json()
        columns = data.get("statement_response", {}).get("manifest", {}).get("schema", {}).get("columns", [])
        rows = data.get("statement_response", {}).get("result", {}).get("data_array", [])

        if not columns:
            return "No results returned."

        col_names = [col.get("name", "") for col in columns]
        lines = [" | ".join(col_names), " | ".join("---" for _ in col_names)]
        for row in rows:
            lines.append(" | ".join(str(v) if v is not None else "" for v in row))

        return f"Query Result ({len(rows)} rows):\n" + "\n".join(lines)

    except httpx.HTTPStatusError as exc:
        return f"HTTP error: {exc.response.status_code} - {exc.response.text}"


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=f"Run {mcp.name} MCP Streamable-HTTP server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    args = parser.parse_args()
    mcp.run(transport="http", path=f"/mcp", port=args.port, host=args.host)
