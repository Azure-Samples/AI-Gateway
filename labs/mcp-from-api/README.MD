---
name: MCP from REST API
architectureDiagram: images/model-context-protocol.gif
categories:
  - Knowledge & Tools
services:
  - MCP
shortDescription: Transform existing REST APIs to Model Context Protocol with Azure API Management.
detailedDescription: Playground to transform an existing REST API to the Model Context Protocol with Azure API Management. This lab demonstrates how to expose traditional REST APIs through the MCP standard, enabling AI models to interact with your existing services using the protocol.
authors:
  - vieiraae
---

# APIM ❤️ AI Agents

## [Model Context Protocol (MCP) from REST API lab](mcp-from-api.ipynb)

[![flow](../../images/model-context-protocol.gif)](mcp-from-api.ipynb)

Playground to transform an existing REST API to the [Model Context Protocol](https://modelcontextprotocol.io/) with Azure API Management. 

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](mcp-from-api.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
