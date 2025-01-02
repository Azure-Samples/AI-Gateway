# APIM ❤️ OpenAI

## [Backend Circuit Breaking lab](backend-circuit-breaking.ipynb)

[![flow](../../images/backend-circuit-breaking.gif)](backend-circuit-breaking.ipynb)

Playground to try the built-in [backend circuit breaker functionality of APIM](https://learn.microsoft.com/azure/api-management/backends?tabs=bicep) to either an Azure OpenAI endpoints or a mock server.

### Prerequisites

- [Python 3.8 or later version](https://www.python.org/) installed
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed
- [VS Code](https://code.visualstudio.com/) installed
- [An Azure Subscription](https://azure.microsoft.com/free/) with access permissions
- [Access granted to Azure OpenAI](https://aka.ms/oai/access) or just enable the mock service
- [Sign in to Azure with Azure CLI](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### Get started

Proceed by opening the [Jupyter notebook](backend-circuit-breaking.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
