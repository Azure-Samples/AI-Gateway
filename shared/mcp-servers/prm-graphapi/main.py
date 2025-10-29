"""Main application file for MCP server with Microsoft Graph integration."""

import logging
import os
import asyncio
from contextlib import asynccontextmanager

# Set FastMCP configuration before importing
# FastMCP reads these during initialization
if "FASTMCP_HOST" not in os.environ:
    os.environ["FASTMCP_HOST"] = os.getenv("HOST", "0.0.0.0")
if "FASTMCP_PORT" not in os.environ:
    os.environ["FASTMCP_PORT"] = os.getenv("PORT", "8000")

#from mcp.server.fastmcp import FastMCP
from fastmcp import FastMCP, Context
from fastmcp.server.dependencies import get_context
from starlette.applications import Starlette
from starlette.routing import Route, Mount
from starlette.middleware import Middleware
from starlette.middleware.cors import CORSMiddleware
from starlette.requests import Request as StarletteRequest
from starlette.responses import JSONResponse

from config.azure_ad_options import AzureAdOptions
from tools.show_user_profile_tool import ShowUserProfileTool
from controllers.auth_controller import AuthController


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# Load Azure AD configuration
try:
    azure_ad_options = AzureAdOptions.from_env()
    logger.info("Azure AD configuration loaded successfully")
except ValueError as e:
    logger.error(f"Failed to load Azure AD configuration: {e}")
    raise


# Initialize FastMCP server
mcp = FastMCP("remote-mcp-msgraph")


# Initialize the tool
user_profile_tool = ShowUserProfileTool(azure_ad_options)


@mcp.tool()
async def show_user_profile() -> str:
    """Retrieves the current user's profile information from Microsoft Graph API.
    
    This tool uses the On-Behalf-Of (OBO) flow to access Microsoft Graph API
    on behalf of the authenticated user. It requires a valid Bearer token in
    the Authorization header.
    
    Returns:
        A JSON string containing the user's profile information including:
        - displayName: The user's display name
        - email: The user's email address
        - id: The user's unique identifier
        - jobTitle: The user's job title
        - department: The user's department
        - officeLocation: The user's office location
    
    Raises:
        Returns error JSON if authentication fails or user consent is required.
    """
    # Get request from FastMCP context
    ctx = get_context()
    
    if not ctx or not hasattr(ctx, 'request_context'):
        return '{"error": "Request context not available"}'
    
    request = ctx.request_context.request
    return await user_profile_tool.show_user_profile(request)


@mcp.custom_route("/auth/callback", methods=["GET"])
async def auth_callback(request: StarletteRequest):
    """Handle OAuth callback from Azure AD."""
    return await AuthController.callback(request)


@mcp.custom_route("/health", methods=["GET"])
async def health_check(request: StarletteRequest):
    """Health check endpoint."""
    return JSONResponse({"status": "healthy"})

app = mcp.http_app()

if __name__ == "__main__":
    # Configuration is already set via environment variables at module import
    host = os.environ.get("FASTMCP_HOST", "0.0.0.0")
    port = os.environ.get("FASTMCP_PORT", "8000")
    
    logger.info(f"Starting MCP server on {host}:{port}")
    logger.info("Available endpoints:")
    logger.info(f"  - POST /mcp/messages - MCP protocol endpoint")
    logger.info(f"  - GET /auth/callback - OAuth callback")
    logger.info(f"  - GET /health - Health check")
    
    # Use FastMCP's built-in run method
    mcp.run(transport="streamable-http")
