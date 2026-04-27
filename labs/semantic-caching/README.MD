---
name: Semantic Caching
architectureDiagram: images/semantic-caching.gif
categories:
  - Platform Capabilities
  - Models Usage
services:
  - Azure Cache
  - Azure OpenAI
shortDescription: Reduce latency and costs using semantic caching for Azure OpenAI API requests.
detailedDescription: The azure-openai-semantic-cache-lookup policy conducts a cache lookup of responses on Azure OpenAI Chat Completion API and Completion API requests from a pre-configured external cache. It operates by comparing the vector proximity of the prompt to prior requests and using a specific similarity score threshold. Caching responses helps reduce bandwidth and processing demands on the backend Azure OpenAI API, thus reducing latency perceived by API consumers.
tags: []
authors:
  - vieiraae
---

# APIM ❤️ AI Foundry

## [Semantic Caching lab](semantic-caching.ipynb)

[![flow](../../images/semantic-caching.gif)](semantic-caching.ipynb)

Playground to try the [semantic caching policy](https://learn.microsoft.com/azure/api-management/azure-openai-semantic-cache-lookup-policy).

The azure-openai-semantic-cache-lookup policy conducts a cache lookup of responses on Azure OpenAI Chat Completion API and Completion API requests from a pre-configured external cache. It operates by comparing the vector proximity of the prompt to prior requests and using a specific similarity score threshold. Caching responses helps reduce bandwidth and processing demands on the backend Azure OpenAI API, thus reducing latency perceived by API consumers.

### Result

![result](result.png)

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](semantic-caching.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
