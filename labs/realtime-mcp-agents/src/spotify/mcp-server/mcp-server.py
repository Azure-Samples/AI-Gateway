from typing import Any
import httpx, os, uuid
from mcp.server.fastmcp import FastMCP, Context
from starlette.applications import Starlette
from mcp.server.sse import SseServerTransport
from starlette.requests import Request
from starlette.routing import Mount, Route
from mcp.server import Server
import uvicorn
from azure.identity import DefaultAzureCredential
from azure.mgmt.apimanagement import ApiManagementClient
from azure.mgmt.apimanagement.models import AuthorizationContract, AuthorizationAccessPolicyContract, AuthorizationLoginRequestContract


# Initialize FastMCP server for Spotify API
mcp = FastMCP("Spotify")

# Environment variables
APIM_GATEWAY_URL = str(os.getenv("APIM_GATEWAY_URL"))
SUBSCRIPTION_ID = str(os.getenv("SUBSCRIPTION_ID"))
RESOURCE_GROUP_NAME = str(os.getenv("RESOURCE_GROUP_NAME"))
APIM_SERVICE_NAME = str(os.getenv("APIM_SERVICE_NAME"))
AZURE_TENANT_ID = str(os.getenv("AZURE_TENANT_ID"))
AZURE_CLIENT_ID = str(os.getenv("AZURE_CLIENT_ID"))
POST_LOGIN_REDIRECT_URL = str(os.getenv("POST_LOGIN_REDIRECT_URL"))
APIM_IDENTITY_OBJECT_ID = str(os.getenv("APIM_IDENTITY_OBJECT_ID"))
idp = "spotify"

def get_headers(ctx: Context):
    headers = {
        "Content-Type": "application/json",
        "authorizationId": f"{idp.lower()}-{str(id(ctx.session))}",
        "providerId": idp.lower() 
    }
    return headers


@mcp.tool()
async def authorize_spotify(ctx: Context) -> str:
    """Validate Credential Manager connection exists and is connected.
    
    Args:
        idp: The identity provider to authorize
    Returns:
        401: Login URL for the user to authorize the connection
        200: Connection authorized
    """
    print("Authorizing connection...")
    print(f"AZURE_TENANT_ID: {AZURE_TENANT_ID}")
    print(f"APIM Gateway URL: {APIM_GATEWAY_URL}")

    session_id = str(id(ctx.session))
    provider_id = idp.lower()
    authorization_id = f"{provider_id}-{session_id}"
    
    print(f"SessionId: {session_id}")

    print("Creating API Management client...")
    client = ApiManagementClient(
        credential=DefaultAzureCredential(),
        subscription_id=SUBSCRIPTION_ID,
    )

    try:
        response = client.authorization.get(
            resource_group_name=RESOURCE_GROUP_NAME,
            service_name=APIM_SERVICE_NAME,
            authorization_provider_id=idp,
            authorization_id=authorization_id,
        )
        if response.status == "Connected":
            print("Spotify authorization is already connected.")
            return "Connection authorized."
    except Exception as e:
        print(f"Failed to get authorization")

    print("Getting authorization provider...")
    response = client.authorization_provider.get(
        resource_group_name=RESOURCE_GROUP_NAME,
        service_name=APIM_SERVICE_NAME,
        authorization_provider_id=idp,
    )

    authContract: AuthorizationContract = AuthorizationContract(
        authorization_type="OAuth2",
        o_auth2_grant_type="AuthorizationCode"
    )

    print("Creating or updating authorization...")
    response = client.authorization.create_or_update(
        resource_group_name=RESOURCE_GROUP_NAME,
        service_name=APIM_SERVICE_NAME,
        authorization_provider_id=idp,
        authorization_id=authorization_id,
        parameters=authContract
    )

    authPolicyContract: AuthorizationAccessPolicyContract = AuthorizationAccessPolicyContract(
        tenant_id=AZURE_TENANT_ID,
        object_id=APIM_IDENTITY_OBJECT_ID
    )

    print("Creating or updating authorization access policy...")
    response = client.authorization_access_policy.create_or_update(
        resource_group_name=RESOURCE_GROUP_NAME,
        service_name=APIM_SERVICE_NAME,
        authorization_provider_id=idp,
        authorization_id=authorization_id,
        authorization_access_policy_id=str(uuid.uuid4())[:33],
        parameters=authPolicyContract
    )

    authPolicyContract: AuthorizationAccessPolicyContract = AuthorizationAccessPolicyContract(
        tenant_id=AZURE_TENANT_ID,
        object_id=AZURE_CLIENT_ID
    )

    print("Creating or updating authorization access policy...")
    response = client.authorization_access_policy.create_or_update(
        resource_group_name=RESOURCE_GROUP_NAME,
        service_name=APIM_SERVICE_NAME,
        authorization_provider_id=idp,
        authorization_id=authorization_id,
        authorization_access_policy_id=str(uuid.uuid4())[:33],
        parameters=authPolicyContract
    )

    authLoginRequestContract: AuthorizationLoginRequestContract = AuthorizationLoginRequestContract(
        post_login_redirect_url=POST_LOGIN_REDIRECT_URL
    )

    print("Getting authorization link...")
    response = client.authorization_login_links.post(
        resource_group_name=RESOURCE_GROUP_NAME,
        service_name=APIM_SERVICE_NAME,
        authorization_provider_id=idp,
        authorization_id=authorization_id,
        parameters=authLoginRequestContract
    )
    print("Login URL: ", response.login_link)
    return f"Please authorize by opening this link: {response.login_link}"



@mcp.tool()
async def get_user_playlists(ctx: Context) -> str:
    """Get user playlists
     
    Returns:
        Playlists for the user
    """
    response = httpx.get(f"{APIM_GATEWAY_URL}/me/playlists?limit=5", headers=get_headers(ctx))
    if (response.status_code == 200):
        return f"Playlists: {response.json()}"
    else:
        return f"Unable to get playlists. Status code: {response.status_code}, Response: {response.text}"

@mcp.tool()
async def get_player_queue(ctx: Context) -> str:
    """Get playback queue
     
    Returns:
        Playback queue
    """
    response = httpx.get(f"{APIM_GATEWAY_URL}/me/player/queue", headers=get_headers(ctx))
    if (response.status_code == 200):
        return f"Playback queue: {response.json()}"
    else:
        return f"Unable to get playback queue. Status code: {response.status_code}, Response: {response.text}"

@mcp.tool()
async def get_playback_status(ctx: Context) -> str:
    """Get playback status
     
    Returns:
        Playback status
    """
    response = httpx.get(f"{APIM_GATEWAY_URL}/me/player", headers=get_headers(ctx))
    if (response.status_code == 200):
        return f"Playback status: {response.json()}"
    else:
        return f"Unable to get playback status. Status code: {response.status_code}, Response: {response.text}"

@mcp.tool()
async def start_playback(ctx: Context) -> str:
    """Start playback
     
    Returns:
        Confirmation that the playback was started
    """
    response = httpx.put(f"{APIM_GATEWAY_URL}/me/player/play", headers=get_headers(ctx))
    if (response.status_code == 200):
        return f"Playback was started!"
    else:
        return f"Unable to start playback. Status code: {response.status_code}, Response: {response.text}"

@mcp.tool()
async def pause_playback(ctx: Context) -> str:
    """Pause playback
     
    Returns:
        Confirmation of pause
    """
    response = httpx.put(f"{APIM_GATEWAY_URL}/me/player/pause", headers=get_headers(ctx))
    if (response.status_code == 200):
        return f"Playback was paused!"
    else:
        return f"Unable to pause playback. Status code: {response.status_code}, Response: {response.text}"

@mcp.tool()
async def get_my_queue(ctx: Context) -> str:
    """Get my playing queue.
     
    Returns:
        The playing queue
    """
    response = httpx.get(f"{APIM_GATEWAY_URL}/me/player/queue", headers=get_headers(ctx))
    if (response.status_code == 200):
        return f"Playing queue: {response.json()}"
    else:
        return f"Unable to get playing queue. Status code: {response.status_code}, Response: {response.text}"

@mcp.tool()
async def browse_new_releases(ctx: Context) -> str:
    """Get all new releases.
     
    Returns:
        A list of releases
    """
    response = httpx.get(f"{APIM_GATEWAY_URL}/browse/new-releases?limit=5", headers=get_headers(ctx))
    if (response.status_code == 200):
        return f"New Releases: {response.json()}"
    else:
        return f"Unable to List Releases. Status code: {response.status_code}, Response: {response.text}"

@mcp.tool()
async def search(ctx: Context, query: str) -> str:
    """Get items that match the search query.
    
    Args:
        query: search query for an artist, album, or track
    Returns:
        Seach results
    """
    response = httpx.get(f"{APIM_GATEWAY_URL}/search?q={query}&type=artist%2Calbum%2Ctrack&limit=5&market=US", headers=get_headers(ctx))
    print("SEARCH RESULT:", response)
    if (response.status_code == 200):
        return f"Search results: {response.json()}"
    else:
        return f"Unable to search. Status code: {response.status_code}, Response: {response.text}"

# Keep - no change needed
def create_starlette_app(mcp_server: Server, *, debug: bool = False) -> Starlette:
    """Create a Starlette application that can server the provied mcp server with SSE."""
    sse = SseServerTransport("/spotify/mcp/messages/")

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
            Route("/spotify/mcp/sse", endpoint=handle_sse),
            Mount("/spotify/mcp/messages/", app=sse.handle_post_message),
        ],
    )


mcp_server = mcp._mcp_server  

# Bind SSE request handling to MCP server
starlette_app = create_starlette_app(mcp_server, debug=True)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Run MCP SSE-based server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type='int', default=8080, help='Port to listen on')
    args = parser.parse_args()

    uvicorn.run(starlette_app, host=args.host, port=args.port)