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


# Initialize FastMCP server for ServiceNow API
mcp = FastMCP("ServiceNow")

# Environment variables
APIM_GATEWAY_URL = str(os.getenv("APIM_GATEWAY_URL"))
SUBSCRIPTION_ID = str(os.getenv("SUBSCRIPTION_ID"))
RESOURCE_GROUP_NAME = str(os.getenv("RESOURCE_GROUP_NAME"))
APIM_SERVICE_NAME = str(os.getenv("APIM_SERVICE_NAME"))
AZURE_TENANT_ID = str(os.getenv("AZURE_TENANT_ID"))
AZURE_CLIENT_ID = str(os.getenv("AZURE_CLIENT_ID"))
POST_LOGIN_REDIRECT_URL = str(os.getenv("POST_LOGIN_REDIRECT_URL"))
APIM_IDENTITY_OBJECT_ID = str(os.getenv("APIM_IDENTITY_OBJECT_ID"))
idp = "servicenow"

@mcp.tool()
async def authorize_servicenow(ctx: Context) -> str:
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
            print("ServiceNow authorization is already connected.")
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

# Update tools to list incidents, get incident and create incident
@mcp.tool()
async def create_incident(ctx: Context) -> str:
    """Create an incident on Service Now.

    Returns:
        Service now incident
    """

    session_id = str(id(ctx.session))
    provider_id = idp.lower()
    authorization_id = f"{provider_id}-{session_id}"
    
    print(f"SessionId: {session_id}")

    serviceNowIncidentUrl = f"{APIM_GATEWAY_URL}/api/now/v2/table/incident"
    serviceNowHeaders = {
        "Content-Type": "application/json",
        "authorizationId": authorization_id,
        "providerId": provider_id
    }

    serviceNowResponse = httpx.get(serviceNowIncidentUrl, headers=serviceNowHeaders)
    if (serviceNowResponse.status_code == 200):
        incident = serviceNowResponse.json()
        return f"Incident Created: {incident}"
    else:
        return f"Unable to create incident. Status code: {serviceNowResponse.status_code}, Response: {serviceNowResponse.text}"
    
@mcp.tool()
async def list_incidents(ctx: Context, recordLimit: int , fields:str) -> str:
    """Get all incidents in this service now incident.
    
    Args:
        recordLimit: Maximum number of records to return
        fields: Fields to return in response
    
    Returns:
        A list of incidents
    """
    print("Getting the list of incidents...")

    session_id = str(id(ctx.session))
    provider_id = idp.lower()
    authorization_id = f"{provider_id}-{session_id}"
    
    print(f"SessionId: {session_id}")

    serviceNowIncidentUrl = f"{APIM_GATEWAY_URL}/api/now/v2/table/incident"
    #We need to get servicenowId for the policy
    serviceNowHeaders = {
        "Content-Type": "application/json",
        "authorizationId": authorization_id,
        "providerId": provider_id 
    }

    params = {
        "sysparm_fields": fields,
        "sysparm_limit": recordLimit
    }

    serviceNowResponse = httpx.get(serviceNowIncidentUrl, headers=serviceNowHeaders, params=params)
    if (serviceNowResponse.status_code == 200):
        incidents = serviceNowResponse.json()
        return f"Incidents: {incidents}"
    else:
        return f"Unable to List Incidents. Status code: {serviceNowResponse.status_code}, Response: {serviceNowResponse.text}"

@mcp.tool()
async def get_incident(ctx: Context, recordSystemId: str, fields:str) -> str:
    """Get incident with specific record system id
    
    Args:
        recordSystemId: record system identifier for the incident
        fields: Fields to return in response
    
    Returns:
        A specific incidents
    """
    print("Getting the incident...")

    session_id = str(id(ctx.session))
    provider_id = idp.lower()
    authorization_id = f"{provider_id}-{session_id}"
    
    print(f"SessionId: {session_id}")

    serviceNowIncidentUrl = f"{APIM_GATEWAY_URL}/api/now/v2/table/incident/{recordSystemId}"
    #We need to get servicenowId for the policy
    serviceNowHeaders = {
        "Content-Type": "application/json",
        "authorizationId": authorization_id,
        "providerId": provider_id 
    }

    params = {
        "sysparm_fields": fields
    }

    serviceNowResponse = httpx.get(serviceNowIncidentUrl, headers=serviceNowHeaders, params=params)
    if (serviceNowResponse.status_code == 200):
        incident = serviceNowResponse.json()
        return f"Incident: {incident}"
    else:
        return f"Unable to Get Incidents. Status code: {serviceNowResponse.status_code}, Response: {serviceNowResponse.text}"

# Keep - no change needed
def create_starlette_app(mcp_server: Server, *, debug: bool = False) -> Starlette:
    """Create a Starlette application that can server the provied mcp server with SSE."""
    sse = SseServerTransport("/servicenow/messages/")

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
            Route("/servicenow/sse", endpoint=handle_sse),
            Mount("/servicenow/messages/", app=sse.handle_post_message),
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