import os

from graphql_mcp import GraphQLMCP


graphql_url = os.getenv(
    "GRAPHQL_URL",
    "https://countries.trevorblades.com/graphql",
)

server = GraphQLMCP.from_remote_url(
    url=graphql_url,
    name="Countries GraphQL API",
    allow_mutations=False,
    timeout=30,
)

app = server.http_app(
    transport="streamable-http",
    stateless_http=True,
)