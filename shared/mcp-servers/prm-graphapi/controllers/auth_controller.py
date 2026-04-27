"""Authentication controller for handling OAuth callbacks."""

import logging
from starlette.responses import HTMLResponse
from starlette.requests import Request


logger = logging.getLogger(__name__)


class AuthController:
    """Controller for handling authentication callbacks."""
    
    @staticmethod
    async def callback(request: Request) -> HTMLResponse:
        """Handle OAuth callback from Azure AD.
        
        Args:
            request: The Starlette request object.
            
        Returns:
            An HTML response indicating success or error.
        """
        code = request.query_params.get("code")
        error = request.query_params.get("error")
        state = request.query_params.get("state")
        
        if error:
            logger.warning(f"Authentication callback received error: {error}")
            return HTMLResponse(content=AuthController._generate_error_html(error))
        
        if code:
            logger.info("Authentication callback received authorization code successfully")
            return HTMLResponse(content=AuthController._generate_success_html())
        
        logger.warning("Authentication callback received without code or error")
        return HTMLResponse(
            content=AuthController._generate_error_html("No authorization code or error received")
        )
    
    @staticmethod
    def _generate_success_html() -> str:
        """Generate success HTML page.
        
        Returns:
            HTML string for success page.
        """
        return """
<!DOCTYPE html>
<html>
<head>
    <title>Authentication Successful</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .success { color: #28a745; }
        .icon { font-size: 48px; text-align: center; margin-bottom: 20px; }
        h1 { color: #333; text-align: center; }
        p { color: #666; line-height: 1.6; }
        .highlight { background-color: #e7f3ff; padding: 15px; border-left: 4px solid #007bff; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Authentication Successful!</h1>
        <p>You have successfully logged in and granted the required permissions.</p>
        <div class="highlight">
            <strong>Next Steps:</strong>
            <ul>
                <li>You can now close this browser window</li>
                <li>Return to your AI Agent and try using the MCP server again</li>
                <li>The server should now be able to access your Microsoft Graph data</li>
            </ul>
        </div>
        <p><em>Thank you for completing the authentication process!</em></p>
    </div>
</body>
</html>
"""
    
    @staticmethod
    def _generate_error_html(error: str) -> str:
        """Generate error HTML page.
        
        Args:
            error: The error message to display.
            
        Returns:
            HTML string for error page.
        """
        return f"""
<!DOCTYPE html>
<html>
<head>
    <title>Authentication Error</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }}
        .container {{ max-width: 600px; margin: 0 auto; background-color: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .error {{ color: #dc3545; }}
        .icon {{ font-size: 48px; text-align: center; margin-bottom: 20px; }}
        h1 {{ color: #333; text-align: center; }}
        p {{ color: #666; line-height: 1.6; }}
        .highlight {{ background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Authentication Error</h1>
        <p>There was an error during the authentication process:</p>
        <div class="highlight">
            <strong>Error:</strong> {error}
        </div>
        <p>Please try the authentication process again or contact your administrator if the problem persists.</p>
    </div>
</body>
</html>
"""
