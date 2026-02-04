---
name: Gemini Models
architectureDiagram: images/gemini-models.gif
categories:
  - Models Usage
  - Platform Capabilities
services:
  - Gemini
  - Multi-Cloud AI
shortDescription: Access Google Gemini models through Azure API Management with native and OpenAI compatibility.
detailedDescription: Playground to try Gemini Models served through the AI Gateway. This lab creates two APIs - one with native Gemini API compatibility and another one with OpenAI compatibility. Learn to integrate third-party AI models through Azure API Management for unified governance and monitoring.
authors:
  - vieiraae
---

# APIM ❤️ 3rd Party Models

## [Gemini Models lab](gemini-models.ipynb)

[![flow](../../images/gemini-models.gif)](gemini-models.ipynb)

Playground to try Gemini Models served trough the AI Gateway. This lab creates two API's: one with native Gemini API compatibility and another one with OpenAI compatibility.

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)
- [Gemini API Key from Google](https://aistudio.google.com/apikey)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](gemini-models.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
