---
name: OpenAI Agents
architectureDiagram: images/openai-agents.gif
categories:
  - AI Agents
services:
  - Assistants API
  - Azure OpenAI
shortDescription: Build AI agents using OpenAI's Assistants API through Azure.
detailedDescription: Explore building AI agents using OpenAI's Assistants API deployed on Azure. This lab demonstrates how to create assistants with custom instructions, enable code interpreter and retrieval capabilities, manage threads and messages, and expose these capabilities through Azure API Management for secure, scalable agent deployments.
tags: []
authors:
  - vieiraae
---

# APIM ❤️ AI Agents

## [OpenAI Agents lab](openai-agents.ipynb)

[![flow](../../images/openai-agents.gif)](openai-agents.ipynb)

Playground to try the [OpenAI Agents](https://openai.github.io/openai-agents-python/) with Azure OpenAI models and API based tools through Azure API Management. This enables limitless opportunities for AI agents while maintaining control through Azure API Management!

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

▶️ Click `Run All` to execute all steps sequentially, or execute them `Step by Step`...

### 🚀 Get started

Proceed by opening the [Jupyter notebook](openai-agents.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
