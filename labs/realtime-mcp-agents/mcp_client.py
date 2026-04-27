"""
Core client functionality for Dolphin MCP.
"""
import logging
import ast

#from mcp.client.sse import sse_client
from mcp.client.streamable_http import streamablehttp_client
from mcp import ClientSession

logger = logging.getLogger("dolphin_mcp")

class HTTPMCPClient:
    """Implementation for a Streamable-based MCP server."""

    def __init__(self, server_name: str, url: str):
        self.server_name = server_name
        self.url = url
        self.tools = []
        self._streams_context = None
        self._session_context = None
        self.session = None

    async def start(self):
        try:
            self._streams_context = streamablehttp_client(url=self.url)
            streams = await self._streams_context.__aenter__()

            self._session_context = ClientSession(streams[0], streams[1])
            self.session = await self._session_context.__aenter__()

            # Initialize
            await self.session.initialize()
            return True
        except Exception as e:
            logger.error(f"Server {self.server_name}: Streamable connection error: {str(e)}")
            return False

    async def list_tools(self):
        if not self.session:
            return []
        try:
            response = await self.session.list_tools()
            self.tools = [
                {
                    "name": tool.name,
                    "description": tool.description,
                    "inputSchema": tool.inputSchema
                }
                for tool in response.tools
            ]
            return self.tools
        except Exception as e:
            logger.error(f"Server {self.server_name}: List tools error: {str(e)}")
            return []

    async def call_tool(self, tool_name: str, arguments: dict):
        if not self.session:
            return {"error": "Not connected"}
        try:
            response = await self.session.call_tool(tool_name, arguments)
            return response.model_dump() if hasattr(response, 'model_dump') else response
        except Exception as e:
            logger.error(f"Server {self.server_name}: Tool call error: {str(e)}")
            return {"error": str(e)}

    async def stop(self):
        if self.session:
            await self._session_context.__aexit__(None, None, None)
        if self._streams_context:
            await self._streams_context.__aexit__(None, None, None)

class OAI_RT_HTTPMCPClient(HTTPMCPClient):
    def __exit__(self, exc_type, exc_value, traceback):
        print("----------Tool Exited")

    async def list_tools(self):
        if not self.session:
            return []
        try:
            response = await self.session.list_tools()
            self.tools = [
                {
                    "type": "function",
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.inputSchema
                }
                for tool in response.tools
            ]
            print(self.tools)
            return self.tools
        except Exception as e:
            logger.error(f"Server {self.server_name}: List tools error: {str(e)}")
            return []

    async def call_tool(self, tool_call: dict):
        if not self.session:
            return {"error": "Not connected"}
        try:
            response = await self.session.call_tool(tool_call['name'], ast.literal_eval(tool_call['arguments']))
            print(response.model_dump_json())
            oai_response = {
                        "call_id": tool_call['call_id'],
                        "type": "function_call_output",
                        "output": response.model_dump()['content'][0]['text'],
                    }
            # print(oai_response)
            return oai_response
        except Exception as e:
            # logger.error(f"Server {self.server_name}: Tool call error: {str(e)}")
            return {"error": str(e)}