import os
from fastapi import FastAPI, Header, HTTPException
from credential_manager_client import CredentialManagerClient

app = FastAPI(title="Credential Manager Client")

credential_manager_client = CredentialManagerClient(
    tenant_id=str(os.getenv("AZURE_TENANT_ID")),
    subscription_id=str(os.getenv("SUBSCRIPTION_ID")),
    resource_group_name=str(os.getenv("RESOURCE_GROUP_NAME")),
    service_name=str(os.getenv("APIM_SERVICE_NAME")),
    apim_identity_object_id=str(os.getenv("APIM_IDENTITY_OBJECT_ID")),
    post_login_redirect_url=str(os.getenv("POST_LOGIN_REDIRECT_URL"))
)
 

@app.get("/connect")
async def get_login_url(
    provider: str = Header(alias="providerId"),
    id: str = Header(alias="authorizationId"),
):
    """Get the login URL for the given provider and authorization ID.

    Args:
        provider: The authorization provider identifier (header: providerId).
        id: The authorization identifier (header: authorizationId).

    Returns:
        MCP response with the login_url.
    """
    try:
        login_url = credential_manager_client.get_login_url(provider, id)
        return {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
                "content": [
                    {
                        "type": "text",
                        "text": f"Please authorize by opening this link: {login_url}",
                    }
                ]
            },
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import argparse
    import uvicorn
    parser = argparse.ArgumentParser(description="Run Credential Manager API server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    args = parser.parse_args()
    uvicorn.run(app, host=args.host, port=args.port)
