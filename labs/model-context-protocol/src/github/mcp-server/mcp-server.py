from typing import Any
import httpx, os
from mcp.server.fastmcp import FastMCP, Context
from starlette.applications import Starlette
from mcp.server.sse import SseServerTransport
from starlette.requests import Request
from starlette.routing import Mount, Route
from mcp.server import Server
import uvicorn

# Initialize FastMCP server for Github API
mcp = FastMCP("GitHub")

# Constants
POST_LOGIN_REDIRECT_URL = "https://bing.com"
APIM_GATEWAY_URL = os.getenv("APIM_GATEWAY_URL")

#region: GITHUB API
@mcp.tool()
async def get_user(ctx: Context) -> str:
    """Get user associated with GitHub access token.

    Returns:
        GitHub user information
    """
    sessionId = str(id(ctx.session))
    providerId = "github"
    authorizationId = f"{providerId}-{sessionId}"
    tokenUrl = f"{APIM_GATEWAY_URL}/token"
    tokenHeaders = {
        "providerId": providerId,
        "authorizationId": authorizationId,
        "Content-Type": "application/json"
    }
    
    print(f"SessionId: {sessionId}")

    tokenResponse = httpx.get(tokenUrl, headers=tokenHeaders)
    if (tokenResponse.status_code == 200):
        token = tokenResponse.json().get("access_token")
        if not token:
            return "Access token not found in response"
    else:
        return f"Unable to get token. Status code: {tokenResponse.status_code}"
    
    githubUserUrl = f"{APIM_GATEWAY_URL}/user"
    githubHeaders = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "API Management"
    }

    githubUserResponse = httpx.get(githubUserUrl, headers=githubHeaders)
    if (githubUserResponse.status_code == 200):
        user = githubUserResponse.json()
        return f"User: {user}"
    else:
        return "Unable to get user"
    
@mcp.tool()
async def get_issues(ctx: Context, username: str, repo: str) -> str:
    """Get all issues for the specified repository for the authenticated user.
    
    Args:
        username: The GitHub username
        repo: The repository name
    
    Returns:
        A list of issues
    """
    
    sessionId = str(id(ctx.session))
    providerId = "github"
    authorizationId = f"{providerId}-{sessionId}"
    tokenUrl = f"{APIM_GATEWAY_URL}/token"
    tokenHeaders = {
        "providerId": providerId,
        "authorizationId": authorizationId,
        "Content-Type": "application/json"
    }
    
    print(f"SessionId: {sessionId}")

    tokenResponse = httpx.get(tokenUrl, headers=tokenHeaders)
    if (tokenResponse.status_code == 200):
        token = tokenResponse.json().get("access_token")
        if not token:
            return "Access token not found in response"
    else:
        return f"Unable to get token. Status code: {tokenResponse.status_code}"
    
    # Get all issues for the specified repository from GitHub API
    githubUrl = f"https://api.github.com/repos/{username}/{repo}/issues"
    githubHeaders = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "API Management"
    }

    githubResponse = httpx.get(githubUrl, headers=githubHeaders)
    if (githubResponse.status_code == 200):
        issues = githubResponse.json()
        return f"Issues: {issues}"
    else:
        return f"Unable to get issues. Status code: {githubResponse.status_code}, Response: {githubResponse.text}"

#region: MCP AUTH
@mcp.tool()
async def authorize_github(ctx: Context) -> str:
    """Validate Credential Manager connection exists and is connected.
    
    Args:
        idp: The identity provider to authorize
    Returns:
        401: Login URL for the user to authorize the connection
        200: Connection authorized
    """
    print("Authorizing connection...")
    idp = "github"
    sessionId = str(id(ctx.session))
    providerId = idp.lower()
    authorizationId = f"{providerId}-{sessionId}"
    
    print(f"SessionId: {sessionId}")

    # Define request to API Management Gateway
    requestUrl = f"{APIM_GATEWAY_URL}/authorize"
    headers = {
        "providerId": providerId,
        "authorizationId": authorizationId,
        "postLoginRedirectUrl": POST_LOGIN_REDIRECT_URL
    }

    print(f"Request URL: {requestUrl}")
    
    # Execute request
    response = httpx.post(requestUrl, headers=headers)

    # If authorized, return success message
    if response.status_code == 200:
        return "Connection authorized"
    
    # If unauthorized, return login URL in a structured format
    if response.status_code == 401:
        try:
            response_data = response.json()
            login_url = response_data.get("loginUrl")
            if login_url:
                return f"Authorization required. Please visit this URL to authorize: {login_url}"
            else:
                return "Authorization required but no login URL was provided"
        except Exception as e:
            return f"Authorization required but failed to parse response: {str(e)}"
    
    # Handle other error cases
    return f"Unable to authorize connection. Status code: {response.status_code}"
    #endregion

def create_starlette_app(mcp_server: Server, *, debug: bool = False) -> Starlette:
    """Create a Starlette application that can server the provied mcp server with SSE."""
    sse = SseServerTransport("/github/messages/")

    async def handle_sse(request: Request) -> None:
        print(f"handling sse")

        async with sse.connect_sse(
                request.scope,
                request.receive,
                request._send,  
        ) as (read_stream, write_stream):
            await mcp_server.run(
                read_stream,
                write_stream,
                mcp_server.create_initialization_options(),
            )

    return Starlette(
        debug=debug,
        routes=[
            Route("/github/sse", endpoint=handle_sse),
            Mount("/github/messages/", app=sse.handle_post_message),
        ],
    )


mcp_server = mcp._mcp_server  

# Bind SSE request handling to MCP server
starlette_app = create_starlette_app(mcp_server, debug=True)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Run MCP SSE-based server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8080, help='Port to listen on')
    args = parser.parse_args()

    uvicorn.run(starlette_app, host=args.host, port=args.port)