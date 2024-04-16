# APIM ❤️ OpenAI

## [SLM self hosting lab](slm-self-hosting.ipynb)
![flow](../../images/slm-self-hosting.gif)

Playground to try the self-hosted [phy-2 Small Language Model (SLM)](https://www.microsoft.com/en-us/research/blog/phi-2-the-surprising-power-of-small-language-models/) trough the [APIM self-hosted gateway](https://learn.microsoft.com/en-us/azure/api-management/self-hosted-gateway-overview) with OpenAI API compatibility.

Phi-2 is a Transformer with 2.7 billion parameters. It was trained using the same data sources as Phi-1.5, augmented with a new data source that consists of various NLP synthetic texts and filtered websites (for safety and educational value).

The APIM self-hosted gateway is a containerized version of the default managed gateway. It's useful for scenarios such as placing gateways in the same environments where you host your APIs. Like in this experiment where we self-host the phi-2 API. This enable use cases where the SLM is running on-premises 

### Prerequisites
- [Python 3.8 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [An Azure Subscription](https://azure.microsoft.com/en-us/free/) with Contributor permissions
- [Access granted to Azure OpenAI](https://aka.ms/oai/access) or just enable the mock service
- [Sign in to Azure with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started
Proceed by opening the [Jupyter notebook](slm-self-hosting.ipynb), and follow the steps provided.

### 🗑️ Clean up resources
When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.