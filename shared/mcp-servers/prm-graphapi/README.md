# Python MCP Server with Microsoft Graph Integration

This is a Python implementation of an MCP (Model Context Protocol) server that integrates with Microsoft Graph API using the On-Behalf-Of (OBO) authentication flow. It's built using [FastMCP](https://gofastmcp.com/getting-started/welcome)

## Features

- **MCP Server**: Implements the Model Context Protocol using FastMCP
- **Microsoft Graph Integration**: Retrieves user profile information via Microsoft Graph API
- **Managed Identity**: Uses managed identities for authenticating the application against Entra (no certs or secrets to manage)
- **On-Behalf-Of Flow**: Uses Azure AD OBO flow with Managed Identity for secure authentication
- **OAuth Callback**: Handles user consent via OAuth callback endpoint
- **Streamable HTTP**: Built on FastMCP's streamable HTTP transport
- **Run in CLI or Containers**: You can run the same code either in compute or in a container (as long as you can get a managed identity token)

## Architecture

The application consists of several components:

- **main.py**: Application entry point with FastMCP and custom routes (for health and callback)
- **config/azure_ad_options.py**: Azure AD configuration management
- **utilities/graph_client_helper.py**: Helper for creating Microsoft Graph clients with OBO flow
- **tools/show_user_profile_tool.py**: MCP tool implementation for fetching user profiles from GraphAPI
- **controllers/auth_controller.py**: OAuth callback handler

## Prerequisites

- Python 3.9 or higher
- Azure AD application with appropriate permissions
- Managed Identity configured for federated credentials

## Installation

1. Clone the repository and navigate to this directory:
   ```bash
   cd mcp-prm-server
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Copy `.env.example` to `.env` and configure your Azure AD settings:
   ```bash
   cp .env.example .env
   ```

5. Edit `.env` with your actual Azure AD configuration:
   ```
   AZURE_TENANT_ID=your-tenant-id
   AZURE_CLIENT_ID=your-client-id
   AZURE_MANAGED_IDENTITY_CLIENT_ID=your-managed-identity-client-id
   HOST=0.0.0.0
   PORT=8000
   ```

## Running the Server

Start the server:

```bash
python main.py
```

The server will start on `http://localhost:8000` by default.

To use a custom IP/Port, or for production/grade use:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

## Endpoints

- **POST /mcp/messages**: MCP protocol endpoint (StreamableHTTP)
- **GET /auth/callback**: OAuth callback endpoint for user consent
- **GET /health**: Health check endpoint

## MCP Tools

### ShowUserProfileTool

Retrieves the current user's profile information from Microsoft Graph API.

**Required Header:**
- `Authorization: Bearer <access_token>`

**Returns:**
```json
{
  "displayName": "John Doe",
  "email": "john.doe@example.com",
  "id": "user-id",
  "jobTitle": "Software Engineer",
  "department": "Engineering",
  "officeLocation": "Building 1"
}
```

**Error Response (Consent Required):**
```json
{
  "error": "User consent required",
  "message": "Please provide the following URL to user and ask them to login in order to call Microsoft Graph API",
  "loginUrl": "https://login.microsoftonline.com/..."
}
```

## Authentication Flow

1. Client calls the MCP tool with a Bearer token
2. Server uses OBO flow to exchange the token for Microsoft Graph access
3. If consent is required, server returns a login URL
4. User authenticates and grants consent via the /auth/callback endpoint
5. Server can now access Microsoft Graph on behalf of the user

## Development

### Project Structure

```
python-mcp-prm-sonnet/
├── config/
│   ├── __init__.py
│   └── azure_ad_options.py       # Azure AD configuration
├── controllers/
│   ├── __init__.py
│   └── auth_controller.py        # OAuth callback handler  
├── tools/
│   ├── __init__.py
│   └── show_user_profile_tool.py # User profile MCP tool
├── utilities/
│   ├── __init__.py
│   └── graph_client_helper.py    # Graph client with OBO flow
├── main.py                       # Application entry point
├── requirements.txt              # Python dependencies
├── .env.example                  # Environment variables template
├── .gitignore                    # Git ignore file
└── README.md                     # This file
```

### Testing

Test the health endpoint:
```bash
curl http://localhost:8000/health
```

Expected response:
```json
{"status":"healthy"}
```

## Troubleshooting

### Import Errors

If you see import errors like `cannot import name 'AuthenticationError'`, ensure all dependencies are installed:
```bash
pip install -r requirements.txt
```

### Environment Variables Not Found

Make sure you have a `.env` file with all required variables, or set them as environment variables:
```bash
export AZURE_TENANT_ID=your-tenant-id
export AZURE_CLIENT_ID=your-client-id
export AZURE_MANAGED_IDENTITY_CLIENT_ID=your-managed-identity-client-id
```

### Server Not Starting

Check the logs for detailed error messages. Common issues:
- Missing Azure AD configuration
- Port already in use
- Python version < 3.9

## License

This code is provided as is without guarantee or warranty, please ensure it passes all your internal testing before moving into production.

