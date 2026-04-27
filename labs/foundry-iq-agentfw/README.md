---
name: "Foundry IQ with Microsoft Agent Framework"
architectureDiagram: images/foundry-iq-agentfw.gif
categories:
  - AI Agents
  - Knowledge & Tools
services:
  - Azure AI Foundry
  - Azure AI Search
  - Azure API Management
shortDescription: Integrate Microsoft Agent Framework with Foundry IQ Knowledge Base via AzureAISearchContextProvider, with APIM as the AI Gateway.
detailedDescription: End-to-end lab integrating the Microsoft Agent Framework with a Foundry IQ Knowledge Base using the AzureAISearchContextProvider. APIM serves as the AI Gateway for embedding traffic and provides unified observability. Demonstrates both semantic (fast hybrid search) and agentic (intelligent multi-hop retrieval) modes. Based on the official Agent Framework + Foundry IQ integration pattern.
authors:
  - nourshaker-msft
---

# APIM ❤️ Foundry IQ

## [Foundry IQ with Microsoft Agent Framework lab](foundry-iq-agentfw.ipynb)

[![flow](../../images/foundry-iq-agentfw.gif)](foundry-iq-agentfw.ipynb)

This lab integrates the **Microsoft Agent Framework** with a **Foundry IQ Knowledge Base** using the `AzureAISearchContextProvider`, with **Azure API Management** serving as the AI Gateway for embedding traffic.

### What you'll build

1. **Azure AI Search Knowledge Base** — Foundry IQ agentic retrieval pipeline with vector + semantic search
2. **APIM AI Gateway** — Managed identity auth, token metrics emission for all OpenAI embedding traffic
3. **Agent Framework ChatAgent** — Agent with `AzureAISearchContextProvider` for grounded answers with citations
4. **Two retrieval modes** — Semantic (fast hybrid search) and Agentic (Foundry IQ intelligent multi-hop retrieval)

### Key APIM integration points

| Traffic Path | APIM Feature |
|-------------|--------------|
| Embedding generation (vectorizer + upload) | Token metrics, managed identity auth |
| All OpenAI traffic | Centralized observability via Application Insights |

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](foundry-iq-agentfw.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
