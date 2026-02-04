---
name: Built-in Logging
architectureDiagram: images/built-in-logging.gif
categories:
  - Platform Capabilities
services:
  - Application Insights
  - Log Analytics
shortDescription: Enable comprehensive logging for debugging and monitoring AI Gateway operations.
detailedDescription: Configure built-in logging capabilities in the AI Gateway to capture detailed request and response data. This lab covers how to set up logging to Application Insights and Log Analytics, configure log levels, implement custom logging policies, and build queries to analyze API traffic patterns and troubleshoot issues.
tags: []
authors:
  - vieiraae
---

# APIM ❤️ AI Foundry

## [Built-in logging lab](built-in-logging.ipynb)

[![flow](../../images/built-in-logging.gif)](built-in-logging.ipynb)

Playground to try the [built-in LLM logging capabilities of API Management](https://learn.microsoft.com/en-us/azure/api-management/monitor-api-management#modify-api-logging-settings). Consumed tokens, prompts and completions are logged automatically into Azure Monitor.

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](built-in-logging.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
