---
name: Token Metrics Emitting
architectureDiagram: images/token-metrics-emitting.gif
categories:
  - Platform Capabilities
  - Governance & Responsible AI
services:
  - Azure Monitor
  - Application Insights
shortDescription: Emit and track detailed token usage metrics for cost analysis and optimization.
detailedDescription: Learn how to emit detailed token usage metrics from Azure API Management to Azure Monitor and Application Insights. This lab demonstrates how to track prompt tokens, completion tokens, and total token usage across different models and users. Build dashboards and alerts to monitor costs and usage patterns in real-time.
authors:
  - vieiraae
---

# APIM ❤️ AI Foundry

## [Token Metrics Emitting lab](token-metrics-emitting.ipynb)

[![flow](../../images/token-metrics-emitting.gif)](token-metrics-emitting.ipynb)

Playground to try the [emit token metric policy](https://learn.microsoft.com/azure/api-management/azure-openai-emit-token-metric-policy). The policy sends metrics to Application Insights about consumption of large language model tokens through Azure AI Foundry APIs.

Notes:

- Token count metrics include: Total Tokens, Prompt Tokens, and Completion Tokens.
- This policy supports OpenAI response streaming! Use the [streaming tool](../../tools/streaming.ipynb) to test and troubleshoot response streaming.
- Use the [tracing tool](../../tools/tracing.ipynb) to track the behavior and troubleshoot the [policy](policy.xml).

[View policy configuration](policy.xml)

### Result

![result](result.png)

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](token-metrics-emitting.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
