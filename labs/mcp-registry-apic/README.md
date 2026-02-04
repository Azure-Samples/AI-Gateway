---
name: MCP Registry with API Center
architectureDiagram: images/apic-registry.gif
categories:
  - Knowledge & Tools
  - Platform Capabilities
services:
  - Azure API Center
  - MCP
shortDescription: Centralized MCP server registry using Azure API Center for enterprise governance.
detailedDescription: To unlock the full potential of Model Context Protocol, enterprises need a centralized registry for server discovery and metadata management. Azure API Center serves as a governed, enterprise-grade repository for managing remote MCP servers. This lab demonstrates creating an API Center service and registering example remote MCP servers with centralized oversight for better version control and access management.
tags: []
authors:
  - jukasper
---

# APIM ❤️ MCP Registry

## [MCP Registry with API Center lab](mcp-registry-apic.ipynb)

[![flow](../../images/apic-registry.gif)](mcp-registry-apic.ipynb)

Playground to experiment with Azure API Center as a centralized registry for Model Context Protocol (MCP) servers. This enables enterprise governance and discovery of MCP servers across your organization.

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](mcp-registry-apic.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
