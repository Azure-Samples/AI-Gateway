---
name: Model Context Protocol (MCP)
architectureDiagram: images/model-context-protocol.gif
categories:
  - Knowledge & Tools
  - AI Agents
services:
  - MCP
  - Azure OpenAI
shortDescription: Implement the Model Context Protocol for standardized AI integrations.
detailedDescription: Learn to implement the Model Context Protocol (MCP), an open standard for enabling AI models to securely access external data sources and tools. This lab demonstrates how to set up MCP servers, expose them through Azure API Management, and enable AI models to interact with databases, APIs, and other services using this standardized protocol.
authors:
  - vieiraae
  - nourshaker-msft
---

# APIM ❤️ AI Agents

## [Model Context Protocol (MCP) lab](model-context-protocol.ipynb)

[![flow](../../images/model-context-protocol.gif)](model-context-protocol.ipynb)

Playground to experiment the [Model Context Protocol](https://modelcontextprotocol.io/) with Azure API Management to enable plug & play of tools to LLMs. Leverages the [credential manager](https://learn.microsoft.com/en-us/azure/api-management/credentials-overview) for  managing OAuth 2.0 tokens to backend tools and [client token validation](https://learn.microsoft.com/en-us/azure/api-management/validate-jwt-policy) to ensure end-to-end authentication and authorization.  

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](model-context-protocol.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
