---
name: Function Calling
architectureDiagram: images/function-calling.gif
categories:
  - Models Usage
  - Knowledge & Tools
services:
  - Azure Functions
  - Azure OpenAI
shortDescription: Enable AI models to call external functions and APIs for enhanced capabilities.
detailedDescription: Explore the function calling capabilities of Azure OpenAI models integrated through Azure API Management. This lab demonstrates how to define functions, enable AI models to intelligently call external APIs and services, and process the results. Learn to build AI agents that can interact with real-world systems and data sources.
tags: []
authors:
  - vieiraae
---

# APIM ❤️ OpenAI

## [Function calling lab](function-calling.ipynb)

[![flow](../../images/function-calling.gif)](function-callingg.ipynb)

Playground to try the OpenAI [function calling](https://learn.microsoft.com/azure/ai-services/openai/how-to/function-calling?tabs=non-streaming%2Cpython) feature with an Azure Functions API also managed with APIM.

At a high level you can break down working with functions into three steps:

1. Call the chat completions API with your functions and the user’s input
2. Use the model’s response to call your API or function
3. Call the chat completions API again, including the response from your function to get a final response

### Result

![result](result.png)

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [Pandas Library](https://pandas.pydata.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed
- [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local?tabs=windows%2Cisolated-process%2Cnode-v4%2Cpython-v2%2Chttp-trigger%2Ccontainer-apps&pivots=programming-language-python#install-the-azure-functions-core-tools) installed
- [An Azure Subscription](https://azure.microsoft.com/free/) with Contributor permissions
- [Access granted to Azure OpenAI](https://aka.ms/oai/access) or just enable the mock service
- [Sign in to Azure with Azure CLI](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](built-in-logging.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
