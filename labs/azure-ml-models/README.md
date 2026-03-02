---
name: "Azure ML Model as MCP Server"
categories: ["AI Agents & MCP", "Model Integration"]
services: ["Azure API Management", "Azure Machine Learning", "Azure AI Foundry", "Azure Monitor"]
shortDescription: "Deploy a trained ML model to Azure ML and expose it as an MCP server via APIM for Foundry agents"
detailedDescription: "This lab demonstrates how to take a pre-trained sklearn forecasting model, deploy it to an Azure ML managed online endpoint, expose it as a REST API through Azure API Management, and wrap it as an MCP server for cloud-based agents in Azure AI Foundry. Includes built-in LLM logging for tracking token usage and tool calling, retry policies for resilience, and managed identity authentication."
authors: ["jonesethan"]
---

# APIM ❤️ AI Foundry

## [Azure ML Model as MCP Server lab](azureml-model.ipynb)

Playground to deploy a trained ML model to an Azure ML online endpoint and expose it as an MCP server through Azure API Management for cloud-based agents in Foundry.

![flow](../../images/azure-ml-models.gif)

### Key Features

| Feature | Description |
|---------|-------------|
| **Azure ML Online Endpoint** | Deploy a pre-trained sklearn forecasting model to a managed online endpoint with AAD Token auth |
| **APIM ML Prediction API** | Expose the Azure ML endpoint as a REST API through APIM with managed identity authentication |
| **MCP Server** | Wrap the ML prediction API as an MCP tool (`predict-forecast`) for agent consumption |
| **Built-in LLM Logging** | Track token usage with `llm-emit-token-metric` policy and dimensions (Subscription ID, Client IP, API ID) |
| **Retry Policy** | Automatic retries on 429 (throttled) and 503 (unavailable) errors in the backend section |
| **Managed Identity Auth** | APIM authenticates to Azure ML using its system-assigned managed identity — no API keys needed |

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](azureml-model.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
