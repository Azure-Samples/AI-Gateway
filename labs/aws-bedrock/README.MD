---
name: AWS Bedrock Integration
architectureDiagram: images/aws-bedrock.gif
categories:
  - Models Usage
  - Platform Capabilities
services:
  - Multi-Cloud AI
shortDescription: Access AWS Bedrock models through Azure API Management gateway.
detailedDescription: Build a multi-cloud AI architecture by integrating AWS Bedrock models with Azure API Management. This lab demonstrates how to expose Claude, Llama, and other Bedrock models through your Azure gateway, implement unified authentication and rate limiting across cloud providers, and create a consistent API interface for multi-cloud AI consumption.
tags: []
authors:
  - vieiraae
---

# APIM ❤️ all the Models

## [AWS Bedrock lab](aws-bedrock.ipynb)

[![flow](../../images/aws-bedrock.gif)](aws-bedrock.ipynb)

Playground to try the [AWS Bedrock models](https://learn.microsoft.com/en-us/azure/api-management/amazon-bedrock-passthrough-llm-api) with the AI Gateway. Consumed tokens, prompts and completions are logged automatically into Azure Monitor.

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)



### 🚀 Get started

Proceed by opening the [Jupyter notebook](aws-bedrock.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
