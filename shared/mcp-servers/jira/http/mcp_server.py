import httpx
import os
from fastmcp import FastMCP, Context
from credential_manager import CredentialManager

APIM_GATEWAY_URL = str(os.getenv("APIM_GATEWAY_URL"))

mcp = FastMCP("Jira")

credential_manager = CredentialManager(
    tenant_id=str(os.getenv("AZURE_TENANT_ID")),
    subscription_id=str(os.getenv("SUBSCRIPTION_ID")),
    resource_group_name=str(os.getenv("RESOURCE_GROUP_NAME")),
    service_name=str(os.getenv("APIM_SERVICE_NAME")),
    apim_identity_object_id=str(os.getenv("APIM_IDENTITY_OBJECT_ID")),
    post_login_redirect_url=str(os.getenv("POST_LOGIN_REDIRECT_URL")),
    authorization_provider_id=str(os.getenv("AUTHORIZATION_PROVIDER_ID")),
)

DEFAULT_MAX_RESULTS = 50


def _get_session_id(ctx: Context) -> str:
    """Extract the session id from the MCP context."""
    return str(id(ctx.session))


def _get_jira_headers(session_id: str) -> dict:
    """Build headers for Jira API calls via APIM."""
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


def _format_issue(issue: dict) -> str:
    """Format a Jira issue into a readable string."""
    fields = issue.get("fields", {})
    parts: list[str] = []

    parts.append(f"Key: {issue.get('key', '')}")
    parts.append(f"Summary: {fields.get('summary', '')}")

    status = fields.get("status", {})
    if status:
        parts.append(f"Status: {status.get('name', '')}")

    priority = fields.get("priority", {})
    if priority:
        parts.append(f"Priority: {priority.get('name', '')}")

    issue_type = fields.get("issuetype", {})
    if issue_type:
        parts.append(f"Type: {issue_type.get('name', '')}")

    assignee = fields.get("assignee", {})
    if assignee:
        parts.append(f"Assignee: {assignee.get('displayName', 'Unassigned')}")
    else:
        parts.append("Assignee: Unassigned")

    reporter = fields.get("reporter", {})
    if reporter:
        parts.append(f"Reporter: {reporter.get('displayName', '')}")

    project = fields.get("project", {})
    if project:
        parts.append(f"Project: {project.get('name', '')} ({project.get('key', '')})")

    labels = fields.get("labels", [])
    if labels:
        parts.append(f"Labels: {', '.join(labels)}")

    created = fields.get("created", "")
    if created:
        parts.append(f"Created: {created}")

    updated = fields.get("updated", "")
    if updated:
        parts.append(f"Updated: {updated}")

    return "\n".join(parts)


def _format_issue_detail(issue: dict) -> str:
    """Format a Jira issue with full description into a readable string."""
    base = _format_issue(issue)
    fields = issue.get("fields", {})
    parts = [base]

    description = fields.get("description", "")
    if description:
        parts.append(f"\nDescription:\n{description}")

    comments = fields.get("comment", {}).get("comments", [])
    if comments:
        parts.append(f"\nComments ({len(comments)}):")
        for comment in comments:
            author = comment.get("author", {}).get("displayName", "Unknown")
            body = comment.get("body", "")
            created = comment.get("created", "")
            parts.append(f"  [{created}] {author}: {body}")

    return "\n".join(parts)


@mcp.tool()
async def search_issues(ctx: Context, jql: str, max_results: int = DEFAULT_MAX_RESULTS) -> str:
    """Search for Jira issues using JQL (Jira Query Language).

    Args:
        jql: A JQL query string. Examples:
            - 'project = ENG AND status = "In Progress"'
            - 'assignee = currentUser() AND resolution = Unresolved'
            - 'labels = bug AND priority = High ORDER BY created DESC'
            - 'text ~ "login error"'
        max_results: Maximum number of results to return (default 50, max 100).

    Returns:
        A list of matching issues with key, summary, status, and assignee,
        or a message with the login URL if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_jira_headers(session_id)
    print(f"Searching Jira: '{jql}' SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.post(
        f"{APIM_GATEWAY_URL}/rest/api/3/search",
        headers=headers,
        json={
            "jql": jql,
            "maxResults": min(max_results, 100),
            "fields": [
                "summary", "status", "priority", "issuetype",
                "assignee", "reporter", "project", "labels",
                "created", "updated",
            ],
        },
    )
    if response.status_code != 200:
        return f"Search failed. Status code: {response.status_code}, Response: {response.text}"

    data = response.json()
    issues = data.get("issues", [])
    total = data.get("total", 0)

    if not issues:
        return "No issues found."

    parts = [f"Found {total} issue(s) (showing {len(issues)}):\n"]
    for issue in issues:
        parts.append(_format_issue(issue))
        parts.append("---")

    return "\n".join(parts)


@mcp.tool()
async def get_issue(ctx: Context, issue_key: str) -> str:
    """Get a Jira issue by its key, including description and comments.

    Args:
        issue_key: The issue key (e.g. "ENG-123", "PROJ-456").

    Returns:
        Full issue details including description and comments,
        or a message with the login URL if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_jira_headers(session_id)
    print(f"Getting issue {issue_key}... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.get(
        f"{APIM_GATEWAY_URL}/rest/api/3/issue/{issue_key}",
        headers=headers,
        params={
            "fields": "summary,status,priority,issuetype,assignee,reporter,"
                      "project,labels,created,updated,description,comment",
        },
    )
    if response.status_code != 200:
        return f"Unable to get issue. Status code: {response.status_code}, Response: {response.text}"

    return _format_issue_detail(response.json())


@mcp.tool()
async def create_issue(
    ctx: Context,
    project_key: str,
    summary: str,
    issue_type: str = "Task",
    description: str | None = None,
    priority: str | None = None,
    labels: list[str] | None = None,
    assignee_account_id: str | None = None,
) -> str:
    """Create a new Jira issue.

    Args:
        project_key: The project key (e.g. "ENG").
        summary: The issue summary / title.
        issue_type: The issue type name (default "Task"). Common values:
            "Bug", "Task", "Story", "Epic", "Sub-task".
        description: Optional plain-text description for the issue.
        priority: Optional priority name (e.g. "High", "Medium", "Low").
        labels: Optional list of label strings to apply.
        assignee_account_id: Optional Atlassian account ID for the assignee.

    Returns:
        The created issue key and URL, or a message with the login URL
        if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_jira_headers(session_id)
    print(f"Creating issue in {project_key}... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    fields: dict = {
        "project": {"key": project_key},
        "summary": summary,
        "issuetype": {"name": issue_type},
    }

    if description:
        # Atlassian Document Format (ADF) for API v3
        fields["description"] = {
            "type": "doc",
            "version": 1,
            "content": [
                {
                    "type": "paragraph",
                    "content": [{"type": "text", "text": description}],
                }
            ],
        }

    if priority:
        fields["priority"] = {"name": priority}

    if labels:
        fields["labels"] = labels

    if assignee_account_id:
        fields["assignee"] = {"accountId": assignee_account_id}

    response = httpx.post(
        f"{APIM_GATEWAY_URL}/rest/api/3/issue",
        headers=headers,
        json={"fields": fields},
    )
    if response.status_code not in (200, 201):
        return f"Unable to create issue. Status code: {response.status_code}, Response: {response.text}"

    data = response.json()
    key = data.get("key", "")
    self_url = data.get("self", "")
    return f"Issue created successfully.\nKey: {key}\nAPI URL: {self_url}"


@mcp.tool()
async def add_comment(ctx: Context, issue_key: str, body: str) -> str:
    """Add a comment to an existing Jira issue.

    Args:
        issue_key: The issue key (e.g. "ENG-123").
        body: The comment text.

    Returns:
        Confirmation of the created comment, or a message with the login URL
        if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_jira_headers(session_id)
    print(f"Adding comment to {issue_key}... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    payload = {
        "body": {
            "type": "doc",
            "version": 1,
            "content": [
                {
                    "type": "paragraph",
                    "content": [{"type": "text", "text": body}],
                }
            ],
        }
    }

    response = httpx.post(
        f"{APIM_GATEWAY_URL}/rest/api/3/issue/{issue_key}/comment",
        headers=headers,
        json=payload,
    )
    if response.status_code not in (200, 201):
        return f"Unable to add comment. Status code: {response.status_code}, Response: {response.text}"

    data = response.json()
    return f"Comment added successfully. Comment ID: {data.get('id', '')}"


@mcp.tool()
async def transition_issue(ctx: Context, issue_key: str, transition_name: str) -> str:
    """Transition a Jira issue to a new status.

    First retrieves available transitions, then applies the matching one.

    Args:
        issue_key: The issue key (e.g. "ENG-123").
        transition_name: The name of the target transition/status
            (e.g. "In Progress", "Done", "To Do").

    Returns:
        Confirmation of the transition, or a message with the login URL
        if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_jira_headers(session_id)
    print(f"Transitioning {issue_key} to '{transition_name}'... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    # Get available transitions
    response = httpx.get(
        f"{APIM_GATEWAY_URL}/rest/api/3/issue/{issue_key}/transitions",
        headers=headers,
    )
    if response.status_code != 200:
        return f"Unable to get transitions. Status code: {response.status_code}, Response: {response.text}"

    transitions = response.json().get("transitions", [])
    target = transition_name.lower()
    match = next(
        (t for t in transitions if t.get("name", "").lower() == target),
        None,
    )

    if not match:
        available = ", ".join(f"'{t.get('name', '')}'" for t in transitions)
        return f"Transition '{transition_name}' not found. Available transitions: {available}"

    # Execute transition
    response = httpx.post(
        f"{APIM_GATEWAY_URL}/rest/api/3/issue/{issue_key}/transitions",
        headers=headers,
        json={"transition": {"id": match["id"]}},
    )
    if response.status_code != 204:
        return f"Unable to transition issue. Status code: {response.status_code}, Response: {response.text}"

    return f"Issue {issue_key} transitioned to '{match.get('name', transition_name)}' successfully."


@mcp.tool()
async def assign_issue(ctx: Context, issue_key: str, account_id: str | None = None) -> str:
    """Assign a Jira issue to a user, or unassign it.

    Args:
        issue_key: The issue key (e.g. "ENG-123").
        account_id: The Atlassian account ID of the user to assign.
            Pass None or omit to unassign the issue.

    Returns:
        Confirmation of the assignment, or a message with the login URL
        if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_jira_headers(session_id)
    action = f"to {account_id}" if account_id else "(unassigning)"
    print(f"Assigning {issue_key} {action}... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.put(
        f"{APIM_GATEWAY_URL}/rest/api/3/issue/{issue_key}/assignee",
        headers=headers,
        json={"accountId": account_id},
    )
    if response.status_code != 204:
        return f"Unable to assign issue. Status code: {response.status_code}, Response: {response.text}"

    if account_id:
        return f"Issue {issue_key} assigned to account {account_id} successfully."
    return f"Issue {issue_key} unassigned successfully."


@mcp.tool()
async def get_projects(ctx: Context) -> str:
    """List Jira projects accessible to the authenticated user.

    Returns:
        A list of projects with keys and names,
        or a message with the login URL if not yet authorized.
    """
    session_id = _get_session_id(ctx)
    headers = _get_jira_headers(session_id)
    print(f"Getting projects... SessionId: {session_id}")

    auth_message = await _ensure_authorized(session_id)
    if auth_message:
        return auth_message

    response = httpx.get(
        f"{APIM_GATEWAY_URL}/rest/api/3/project/search",
        headers=headers,
        params={"maxResults": 100},
    )
    if response.status_code != 200:
        return f"Unable to get projects. Status code: {response.status_code}, Response: {response.text}"

    data = response.json()
    projects = data.get("values", [])
    if not projects:
        return "No projects found."

    parts = [f"Found {len(projects)} project(s):\n"]
    for proj in projects:
        name = proj.get("name", "")
        key = proj.get("key", "")
        ptype = proj.get("projectTypeKey", "")
        lead = proj.get("lead", {}).get("displayName", "")
        line = f"- {name} (key: {key}, type: {ptype})"
        if lead:
            line += f" — Lead: {lead}"
        parts.append(line)

    return "\n".join(parts)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=f"Run {mcp.name} MCP Streamable-HTTP server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    args = parser.parse_args()
    mcp.run(transport="http", path=f"/mcp", port=args.port, host=args.host)
