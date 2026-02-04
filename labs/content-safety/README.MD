---
name: Content Safety
architectureDiagram: images/content-safety.gif
categories:
  - Governance & Responsible AI
services:
  - Azure AI Content Safety
  - Azure OpenAI
shortDescription: Implement content filtering and safety checks for AI-generated responses.
detailedDescription: This lab demonstrates how to implement Azure AI Content Safety to filter and moderate content in both requests and responses. Learn how to protect your applications from harmful content including hate speech, violence, self-harm, and sexual content using Azure's advanced content moderation capabilities integrated with Azure API Management.
authors:
  - vieiraae
---

# APIM ❤️ Responsible AI

## [Content Safety lab](content-safety.ipynb)

[![flow](../../images/content-safety.gif)](content-safety.ipynb)

Playground to try the [content safety policy](https://learn.microsoft.com/en-us/azure/api-management/llm-content-safety-policy). The policy enforces content safety checks on any LLM prompts by transmitting them to the [Azure AI Content Safety](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/overview) service before sending to the backend LLM API. When the policy is enabled and Azure AI Content Safety detects malicious content, API Management blocks the request and returns a 403 error code.

[View policy configuration](policy.xml)

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](content-safety.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
