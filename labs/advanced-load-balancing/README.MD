# APIM ❤️ OpenAI

## [Advanced Load Balancing lab](advanced-load-balancing.ipynb)

[![flow](../../images/advanced-load-balancing.gif)](advanced-load-balancing.ipynb)

Playground to try the advanced load balancing to either a list of Azure OpenAI endpoints or mock servers.

This load balancer is based on a custom policy configuration forked from this great [smart load balancer repo](https://github.com/andredewes/apim-aoai-smart-loadbalancing) and adds the following enhancements:

- Loads the load balancer configuration from a named value
- Uses backends to enable the combination with the built-in circuit breaking feature
- The policy doesn't have to be changed to add/modify endpoints or configure the load balancer
- Dynamicly supports any number of OpenAI endpoints

### Prerequisites

- [Python 3.8 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [An Azure Subscription](https://azure.microsoft.com/en-us/free/) with Contributor permissions
- [Access granted to Azure OpenAI](https://aka.ms/oai/access) or just enable the mock service
- [Sign in to Azure with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](advanced-load-balancing.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
