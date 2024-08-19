# APIM ❤️ OpenAI

## AI Gateway Tools

Tools that can be used with existing labs:

- [AI-Gateway Mock server](mock-server/mock-server.ipynb) is designed to mimic the behavior and responses of the OpenAI API, thereby creating an efficient simulation environment suitable for testing and development purposes on the integration with APIM and other use cases. The [app.py](mock-server/app.py) can be customized to tailor the Mock server to specific use cases.
- [Tracing](tracing.ipynb) - Invoke OpenAI API with trace enabled and returns the tracing information.
- [Streaming](streaming.ipynb) - Invoke OpenAI API with stream enabled and returns response in chunks.

### Prerequisites

- [Python 3.8 or later version](https://www.python.org/) installed
- [Pandas Library](https://pandas.pydata.org) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [An Azure Subscription](https://azure.microsoft.com/en-us/free/) with Contributor permissions
- [Access granted to Azure OpenAI](https://aka.ms/oai/access) or just enable the mock service
- [Sign in to Azure with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively)
