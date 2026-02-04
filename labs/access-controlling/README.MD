---
name: Access Controlling
architectureDiagram: images/access-controlling.gif
categories:
  - Governance & Responsible AI
  - Platform Capabilities
services:
  - Entra ID
  - Managed Identity
shortDescription: Implement authentication and authorization for AI Gateway APIs.
detailedDescription: Secure your AI Gateway with comprehensive access control mechanisms. This lab covers implementing OAuth 2.0, Azure AD authentication, API keys, and managed identities. Learn to set up subscription-based access, implement JWT validation, configure CORS policies, and create different access tiers for your AI services.
authors:
  - vieiraae
  - nourshaker-msft
---

# APIM ❤️ AI Foundry

## [Access Controlling lab](access-controlling.ipynb)

[![flow](../../images/access-controlling.gif)](access-controlling.ipynb)

Playground to try the [OAuth 2.0 authorization feature](https://learn.microsoft.com/azure/api-management/api-management-authenticate-authorize-azure-openai#oauth-20-authorization-using-identity-provider) using identity provider to enable more fine-grained access to AI Foundry models by particular users or client.

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](access-controlling.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
