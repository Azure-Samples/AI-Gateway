---
name: Realtime Audio
architectureDiagram: images/realtime-audio.gif
categories:
  - Models Usage
services:
  - Audio Agents
  - Realtime API
  - Azure OpenAI
shortDescription: Enable real-time audio processing and speech-to-speech AI interactions.
detailedDescription: Build real-time audio applications using Azure OpenAI's audio capabilities through Azure API Management. This lab covers setting up WebSocket connections for streaming audio, implementing speech-to-text and text-to-speech conversions, managing real-time conversations, and handling audio streaming efficiently with low latency.
authors:
  - nourshaker-msft
---

# APIM ❤️ OpenAI

## [Azure OpenAI Realtime Audio lab](realtime-audio.ipynb)

[![flow](../../images/realtime-audio.gif)](realtime-audio.ipynb)

Playground to try the APIM integration with the [Azure OpenAI Realtime API](https://learn.microsoft.com/en-us/azure/ai-services/openai/realtime-audio-reference) for text and audio.

### Result

![result](result.png)

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](realtime-audio.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.