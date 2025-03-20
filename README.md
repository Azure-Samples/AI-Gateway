<!-- markdownlint-disable MD033 -->

# APIM ❤️ OpenAI - 🧪 Labs for the [GenAI Gateway capabilities](https://techcommunity.microsoft.com/t5/azure-integration-services-blog/introducing-genai-gateway-capabilities-in-azure-api-management/ba-p/4146525) of [Azure API Management](https://learn.microsoft.com/azure/api-management/api-management-key-concepts)

[![Open Source Love](https://firstcontributions.github.io/open-source-badges/badges/open-source-v1/open-source.svg)](https://github.com/firstcontributions/open-source-badges)

## What's new ✨

➕ **Agentic ✨** experiments with [**Model Context Protocol (MCP)**](labs/model-context-protocol/model-context-protocol.ipynb).  
➕ **Agentic ✨** experiments with [**OpenAI Agents SDK**](labs/openai-agents/openai-agents.ipynb).  
➕ **Agentic ✨** experiments with [**AI Agent Service**](labs/ai-agent-service/ai-agent-service.ipynb) from [Azure AI Foundry](https://azure.microsoft.com/en-us/products/ai-foundry).  
➕ the [**AI Foundry Deepseek**](labs/ai-foundry-deepseek/ai-foundry-deepseek.ipynb) lab with Deepseek R1 model from [Azure AI Foundry](https://azure.microsoft.com/en-us/products/ai-foundry).  
➕ the [**Zero-to-Production**](labs/zero-to-production/zero-to-production.ipynb) lab with an iterative policy exploration to fine-tune the optimal production configuration.  
➕ the [**Terraform flavor  of backend pool load balancing**](labs/backend-pool-load-balancing-tf/backend-pool-load-balancing-tf.ipynb) lab.  
➕ the [**AI Foundry SDK**](labs/ai-foundry-sdk/ai-foundry-sdk.ipynb) lab.  
➕ the [**Content filtering**](labs/content-filtering/content-filtering.ipynb) and [**Prompt shielding**](labs/content-filtering/prompt-shielding.ipynb) labs.  
➕ the [**Model routing**](labs/model-routing/model-routing.ipynb) lab with OpenAI model based routing.  
➕ the [**Prompt flow**](labs/prompt-flow/prompt-flow.ipynb) lab to try the [Azure AI Studio Prompt Flow](https://learn.microsoft.com/azure/ai-studio/how-to/prompt-flow) with Azure API Management.  
➕ `priority` and `weight` parameters to the [**Backend pool load balancing**](labs/backend-pool-load-balancing/backend-pool-load-balancing.ipynb) lab.  
➕ the [**Streaming**](streaming.ipynb) tool to test OpenAI streaming with Azure API Management.  
➕ the [**Tracing**](tools/tracing.ipynb) tool to debug and troubleshoot OpenAI APIs using [Azure API Management tracing capability](https://learn.microsoft.com/azure/api-management/api-management-howto-api-inspector).  
➕ image processing to the [**GPT-4o inferencing**](labs/GPT-4o-inferencing/GPT-4o-inferencing.ipynb) lab.  
➕ the [**Function calling**](labs/function-calling/function-calling.ipynb) lab with a sample API on Azure Functions.

## Contents

1. [🧠 GenAI Gateway](#-genai-gateway)
1. [🧪 Labs with AI Agents](#-labs-with-ai-agents)
1. [🧪 Labs with the Inference API](#-labs-with-the-inference-api)
1. [🧪 Labs based on Azure OpenAI](#-labs-based-on-azure-openai)
1. [🚀 Getting started](#-getting-started)
1. [⛵ Roll-out to production](#-roll-out-to-production)
1. [🔨 Supporting tools](#-supporting-tools)
1. [🏛️ Well-Architected Framework](#-well-architected-framework)    <!-- markdownlint-disable-line MD051 -->
1. [🎒 Show and tell](#-show-and-tell)
1. [🥇 Other Resources](#-other-resources)

The rapid pace of AI advances demands experimentation-driven approaches for organizations to remain at the forefront of the industry. With AI steadily becoming a game-changer for an array of sectors, maintaining a fast-paced innovation trajectory is crucial for businesses aiming to leverage its full potential.

**AI services** are predominantly accessed via **APIs**, underscoring the essential need for a robust and efficient API management strategy. This strategy is instrumental for maintaining control and governance over the consumption of **AI services**.

With the expanding horizons of **AI services** and their seamless integration with **APIs**, there is a considerable demand for a comprehensive **AI Gateway** pattern, which broadens the core principles of API management. Aiming to accelerate the experimentation of advanced use cases and pave the road for further innovation in this rapidly evolving field. The well-architected principles of the **AI Gateway** provides a framework for the confident deployment of **Intelligent Apps** into production.

## 🧠 GenAI Gateway

![AI-Gateway flow](images/ai-gateway.gif)

This repo explores the **AI Gateway** pattern through a series of experimental labs. The [GenAI Gateway capabilities](https://techcommunity.microsoft.com/t5/azure-integration-services-blog/introducing-genai-gateway-capabilities-in-azure-api-management/ba-p/4146525) of [Azure API Management](https://learn.microsoft.com/azure/api-management/api-management-key-concepts) plays a crucial role within these labs, handling AI services APIs, with security, reliability, performance, overall operational efficiency and cost controls. The primary focus is on [Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/overview), which sets the standard reference for Large Language Models (LLM). However, the same principles and design patterns could potentially be applied to any LLM.

Acknowledging the rising dominance of Python, particularly in the realm of AI, along with the powerful experimental capabilities of Jupyter notebooks, the following labs are structured around Jupyter notebooks, with step-by-step instructions with Python scripts, [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview?tabs=bicep) files and [Azure API Management policies](https://learn.microsoft.com/azure/api-management/api-management-howto-policies):

## 🧪 Labs with AI Agents

<!-- Model Context Protocol (MCP) -->
### [**🧪 Model Context Protocol (MCP)**](labs/model-context-protocol.ipynb)

Playground to experiment the [Model Context Protocol](https://modelcontextprotocol.io/) with Azure API Management to enable plug & play of tools to LLMs. Leverages the [credential manager](https://learn.microsoft.com/en-us/azure/api-management/credentials-overview) for  managing OAuth 2.0 tokens to backend tools and [client token validation](https://learn.microsoft.com/en-us/azure/api-management/validate-jwt-policy) to ensure end-to-end authentication and authorization.  

[<img src="images/model-context-protocol-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/model-context-protocol/model-context-protocol.ipynb)

[🦾 Bicep](labs/model-context-protocol/main.bicep) ➕ [⚙️ Policy](labs/model-context-protocol/inference-policy.xml) ➕ [🧾 Notebook](labs/model-context-protocol/model-context-protocol.ipynb)


<!-- OpenAI Agents -->
### [**🧪 OpenAI Agents**](labs/openai-agents/openai-agents.ipynb)

Playground to try the [OpenAI Agents](https://openai.github.io/openai-agents-python/) with Azure OpenAI models and API based tools controlled by Azure API Management.

[<img src="images/openai-agents-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/openai-agents/openai-agents.ipynb)

[🦾 Bicep](labs/openai-agents/main.bicep) ➕ [⚙️ Policy](labs/openai-agents/inference-policy.xml) ➕ [🧾 Notebook](labs/openai-agents/openai-agents.ipynb)

<!-- AI Agent Service -->
### [**🧪 AI Agent Service**](labs/ai-agent-service/ai-agent-service.ipynb)

Use this playground to explore the [Azure AI Agent Service](https://learn.microsoft.com/en-us/azure/ai-services/agents/overview), leveraging Azure API Management to control multiple services, including Azure OpenAI models, Logic Apps Workflows, and OpenAPI-based APIs.

[<img src="images/ai-agent-service-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/ai-agent-service/ai-agent-service.ipynb)

[🦾 Bicep](labs/ai-agent-service/main.bicep) ➕ [⚙️ Policy](labs/ai-agent-service/policy.xml) ➕ [🧾 Notebook](labs/ai-agent-service/ai-agent-service.ipynb)

<!-- Function calling -->
### [**🧪 Function calling**](labs/function-calling/function-calling.ipynb)

Playground to try the OpenAI [function calling](https://learn.microsoft.com/azure/ai-services/openai/how-to/function-calling?tabs=non-streaming%2Cpython) feature with an Azure Functions API that is also managed by Azure API Management.

[<img src="images/function-calling-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/function-calling/function-calling.ipynb)

[🦾 Bicep](labs/function-calling/main.bicep) ➕ [⚙️ Policy](labs/function-calling/policy.xml) ➕ [🧾 Notebook](labs/function-calling/function-calling.ipynb)

## 🧪 Labs with the Inference API

<!-- AI Foundry Deepseek -->
### [**🧪 AI Foundry Deepseek**](labs/ai-foundry-deepseek/ai-foundry-deepseek.ipynb)

Playground to try the [Deepseek R1 model](https://azure.microsoft.com/en-us/blog/deepseek-r1-is-now-available-on-azure-ai-foundry-and-github/) via the AI Model Inference from [Azure AI Foundry](https://azure.microsoft.com/en-us/products/ai-foundry). This lab uses the [Azure AI Model Inference API](https://learn.microsoft.com/en-us/azure/ai-foundry/model-inference/how-to/inference?tabs=python) and two APIM LLM policies: [llm-token-limit](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy) and [llm-emit-token-metric](https://learn.microsoft.com/en-us/azure/api-management/llm-emit-token-metric-policy).

[<img src="images/ai-foundry-deepseek-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/ai-foundry-deepseek/ai-foundry-deepseek.ipynb)

[🦾 Bicep](labs/ai-foundry-deepseek/main.bicep) ➕ [⚙️ Policy](labs/ai-foundry-deepseek/policy.xml) ➕ [🧾 Notebook](labs/ai-foundry-deepseek/ai-foundry-deepseek.ipynb)

<!-- SLM self-hosting -->
### [**🧪 SLM self-hosting**](labs/slm-self-hosting/slm-self-hosting.ipynb) (phy-3)

Playground to try the self-hosted [phy-3 Small Language Model (SLM)](https://azure.microsoft.com/blog/introducing-phi-3-redefining-whats-possible-with-slms/) through the [Azure API Management self-hosted gateway](https://learn.microsoft.com/azure/api-management/self-hosted-gateway-overview) with OpenAI API compatibility.

[<img src="images/slm-self-hosting-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/slm-self-hosting/slm-self-hosting.ipynb)

[🦾 Bicep](labs/slm-self-hosting/main.bicep) ➕ [⚙️ Policy](labs/slm-self-hosting/policy.xml) ➕ [🧾 Notebook](labs/slm-self-hosting/slm-self-hosting.ipynb)

## 🧪 Labs based on Azure OpenAI

<!-- Backend pool load balancing -->
### [**🧪 Backend pool load balancing**](labs/backend-pool-load-balancing/backend-pool-load-balancing.ipynb) - Available with [Bicep](labs/backend-pool-load-balancing/backend-pool-load-balancing.ipynb) and [Terraform](labs/backend-pool-load-balancing-tf/backend-pool-load-balancing-tf.ipynb)

Playground to try the built-in load balancing [backend pool functionality of Azure API Management](https://learn.microsoft.com/azure/api-management/backends?tabs=bicep) to either a list of Azure OpenAI endpoints or mock servers.

[<img src="images/backend-pool-load-balancing-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/backend-pool-load-balancing/backend-pool-load-balancing.ipynb)

[🦾 Bicep](labs/backend-pool-load-balancing/main.bicep) ➕ [⚙️ Policy](labs/backend-pool-load-balancing/policy.xml) ➕ [🧾 Notebook](labs/backend-pool-load-balancing/backend-pool-load-balancing.ipynb)

<!-- Token rate limiting -->
### [**🧪 Token rate limiting**](labs/token-rate-limiting/token-rate-limiting.ipynb)

Playground to try the [token rate limiting policy](https://learn.microsoft.com/azure/api-management/azure-openai-token-limit-policy) to one or more Azure OpenAI endpoints. When the token usage is exceeded, the caller receives a 429.

[<img src="images/token-rate-limiting-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/token-rate-limiting/token-rate-limiting.ipynb)

[🦾 Bicep](labs/token-rate-limiting/main.bicep) ➕ [⚙️ Policy](labs/token-rate-limiting/policy.xml) ➕ [🧾 Notebook](labs/token-rate-limiting/token-rate-limiting.ipynb)

<!-- Token metrics emitting -->
### [**🧪 Token metrics emitting**](labs/token-metrics-emitting/token-metrics-emitting.ipynb)

Playground to try the [emit token metric policy](https://learn.microsoft.com/azure/api-management/azure-openai-emit-token-metric-policy). The policy sends metrics to Application Insights about consumption of large language model tokens through Azure OpenAI Service APIs.

[<img src="images/token-metrics-emitting-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/token-metrics-emitting/token-metrics-emitting.ipynb)

[🦾 Bicep](labs/token-metrics-emitting/main.bicep) ➕ [⚙️ Policy](labs/token-metrics-emitting/policy.xml) ➕ [🧾 Notebook](labs/token-metrics-emitting/token-metrics-emitting.ipynb)

<!-- Semantic caching -->
### [**🧪 Semantic caching**](labs/semantic-caching/semantic-caching.ipynb)

Playground to try the [semantic caching policy](https://learn.microsoft.com/azure/api-management/azure-openai-semantic-cache-lookup-policy). Uses vector proximity of the prompt to previous requests and a specified similarity score threshold.

[<img src="images/semantic-caching-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/semantic-caching/semantic-caching.ipynb)

[🦾 Bicep](labs/semantic-caching/main.bicep) ➕ [⚙️ Policy](labs/semantic-caching/policy.xml) ➕ [🧾 Notebook](labs/semantic-caching/semantic-caching.ipynb)

<!-- Access controlling -->
### [**🧪 Access controlling**](labs/access-controlling/access-controlling.ipynb)

Playground to try the [OAuth 2.0 authorization feature](https://learn.microsoft.com/azure/api-management/api-management-authenticate-authorize-azure-openai#oauth-20-authorization-using-identity-provider) using identity provider to enable more fine-grained access to OpenAPI APIs by particular users or client.

[<img src="images/access-controlling-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/access-controlling/access-controlling.ipynb)

[🦾 Bicep](labs/access-controlling/main.bicep) ➕ [⚙️ Policy](labs/access-controlling/policy.xml) ➕ [🧾 Notebook](labs/access-controlling/access-controlling.ipynb)

<!-- zero-to-production -->
### [**🧪 Zero-to-Production**](labs/zero-to-production/zero-to-production.ipynb)

Playground to create a combination of several policies in an iterative approach. We start with load balancing, then progressively add token emitting, rate limiting, and, eventually, semantic caching. Each of these sets of policies is derived from other labs in this repo.

[<img src="images/zero-to-production-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/zero-to-production/zero-to-production.ipynb)

[🦾 Bicep](labs/zero-to-production/main.bicep) ➕ [⚙️ Policy](labs/zero-to-production/policy-3.xml) ➕ [🧾 Notebook](labs/zero-to-production/zero-to-production.ipynb)

<!-- GPT-4o inferencing -->
### [**🧪 GPT-4o inferencing**](labs/GPT-4o-inferencing/GPT-4o-inferencing.ipynb)

Playground to try the new GPT-4o model. GPT-4o ("o" for "omni") is designed to handle a combination of text, audio, and video inputs, and can generate outputs in text, audio, and image formats.

[<img src="images/GPT-4o-inferencing-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/GPT-4o-inferencing/GPT-4o-inferencing.ipynb)

[🦾 Bicep](labs/GPT-4o-inferencing/main.bicep) ➕ [⚙️ Policy](labs/GPT-4o-inferencing/policy.xml) ➕ [🧾 Notebook](labs/GPT-4o-inferencing/GPT-4o-inferencing.ipynb)

<!-- Model Routing -->
### [**🧪 Model Routing**](labs/model-routing/model-routing.ipynb)

Playground to try routing to a backend based on Azure OpenAI model and version.

[<img src="images/model-routing-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/model-routing/model-routing.ipynb)

[🦾 Bicep](labs/model-routing/main.bicep) ➕ [⚙️ Policy](labs/model-routing/policy.xml) ➕ [🧾 Notebook](labs/model-routing/model-routing.ipynb)

<!-- Vector searching -->
### [**🧪 Vector searching**](labs/vector-searching/vector-searching.ipynb)

Playground to try the [Retrieval Augmented Generation (RAG) pattern](https://learn.microsoft.com/azure/search/retrieval-augmented-generation-overview) with Azure AI Search, Azure OpenAI embeddings and Azure OpenAI completions.

[<img src="images/vector-searching-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/vector-searching/vector-searching.ipynb)

[🦾 Bicep](labs/vector-searching/main.bicep) ➕ [⚙️ Policy](labs/vector-searching/policy.xml) ➕ [🧾 Notebook](labs/vector-searching/vector-searching.ipynb)

<!-- Built-in logging -->
### [**🧪 Built-in logging**](labs/built-in-logging/built-in-logging.ipynb)

Playground to try the [buil-in logging capabilities of Azure API Management](https://learn.microsoft.com/azure/api-management/observability). Logs requests into App Insights to track details and token usage.

[<img src="images/built-in-logging-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/built-in-logging/built-in-logging.ipynb)

[🦾 Bicep](labs/built-in-logging/main.bicep) ➕ [⚙️ Policy](labs/built-in-logging/policy.xml) ➕ [🧾 Notebook](labs/built-in-logging/built-in-logging.ipynb)

<!-- Message storing -->
### [**🧪 Message storing**](labs/message-storing/message-storing.ipynb)

Playground to test storing message details into Cosmos DB through the [Log to event hub](https://learn.microsoft.com/azure/api-management/log-to-eventhub-policy) policy. With the policy we can control which data will be stored in the DB (prompt, completion, model, region, tokens etc.).

[<img src="images/message-storing-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/message-storing/message-storing.ipynb)

[🦾 Bicep](labs/message-storing/main.bicep) ➕ [⚙️ Policy](labs/message-storing/policy.xml) ➕ [🧾 Notebook](labs/message-storing/message-storing.ipynb)

<!-- Prompt flow -->
### [**🧪 Prompt flow**](labs/prompt-flow/prompt-flow.ipynb)

Playground to try the [Azure AI Studio Prompt Flow](https://learn.microsoft.com/azure/ai-studio/how-to/prompt-flow) with Azure API Management.

[<img src="images/prompt-flow-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/prompt-flow/prompt-flow.ipynb)

[🦾 Bicep](labs/prompt-flow/main.bicep) ➕ [⚙️ Policy](labs/prompt-flow/policy.xml) ➕ [🧾 Notebook](labs/prompt-flow/prompt-flow.ipynb)

<!-- Content Filtering -->
### [**🧪 Content Filtering**](labs/content-filtering/content-filtering.ipynb)

Playground to try integrating Azure API Management with [Azure AI Content Safety](https://learn.microsoft.com/azure/ai-services/content-safety/overview) to filter potentially offensive, risky, or undesirable content.

[<img src="images/content-filtering-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/content-filtering/content-filtering.ipynb)

[🦾 Bicep](labs/content-filtering/main.bicep) ➕ [⚙️ Policy](labs/content-filtering/content-filtering-policy.xml) ➕ [🧾 Notebook](labs/content-filtering/content-filtering.ipynb)

<!-- Prompt Shielding -->
### [**🧪 Prompt Shielding**](labs/content-filtering/prompt-shielding.ipynb)

Playground to try Prompt Shields from Azure AI Content Safety service that analyzes LLM inputs and detects User Prompt attacks and Document attacks, which are two common types of adversarial inputs.

[<img src="images/content-filtering-small.gif" alt="flow" style="width: 437px; display: inline-block;" data-target="animated-image.originalImage">](labs/content-filtering/prompt-shielding.ipynb)

[🦾 Bicep](labs/content-filtering/main.bicep) ➕ [⚙️ Policy](labs/content-filtering/prompt-shield-policy.xml) ➕ [🧾 Notebook](labs/content-filtering/prompt-shielding.ipynb)

## Backlog of Labs

This is a list of potential future labs to be developed.

* Real Time API
* Semantic Kernel with Agents
* Logic Apps RAG
* PII handling
* Gemini

> [!TIP]
> Kindly use [the feedback discussion](../../discussions/9) so that we can continuously improve with your experiences, suggestions, ideas or lab requests.

## 🚀 Getting Started

### Prerequisites

* [Python 3.12 or later version](https://www.python.org/) installed
* [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
* [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
* [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
* [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### Quickstart

1. Clone this repo and configure your local machine with the prerequisites. Or just create a [GitHub Codespace](https://codespaces.new/Azure-Samples/AI-Gateway/tree/main) and run it on the browser or in VS Code.
2. Navigate through the available labs and select one that best suits your needs. For starters we recommend the [token rate limiting](labs/token-rate-limiting/token-rate-limiting.ipynb).
3. Open the notebook and run the provided steps.
4. Tailor the experiment according to your requirements. If you wish to contribute to our collective work, we would appreciate your [submission of a pull request](CONTRIBUTING.MD).

> [!NOTE]
> 🪲 Please feel free to open a new [issue](../../issues/new) if you find something that should be fixed or enhanced.

## ⛵ Roll-out to production

We recommend the guidelines and best practices from the [AI Hub Gateway Landing Zone](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator) to implement a central AI API gateway to empower various line-of-business units in an organization to leverage Azure AI services.

## 🔨 Supporting Tools

* [AI-Gateway Mock server](tools/mock-server/mock-server.ipynb) is designed to mimic the behavior and responses of the OpenAI API, thereby creating an efficient simulation environment suitable for testing and development purposes on the integration with Azure API Management and other use cases. The [app.py](tools/mock-server/app.py) can be customized to tailor the Mock server to specific use cases.
* [Tracing](tools/tracing.ipynb) - Invoke OpenAI API with trace enabled and returns the tracing information.
* [Streaming](streaming.ipynb) - Invoke OpenAI API with stream enabled and returns response in chunks.

## 🏛️ Well-Architected Framework

The [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/what-is-well-architected-framework) is a design framework that can improve the quality of a workload. The following table maps labs with the Well-Architected Framework pillars to set you up for success through architectural experimentation.

| Lab  | Security | Reliability | Performance | Operations | Costs |
| -------- | -------- |-------- |-------- |-------- |-------- |
| [Request forwarding](labs/request-forwarding/request-forwarding.ipynb) | [⭐](#%EF%B8%8F-well-architected-framework "Zero trust, keyless approach with manage identities and Azure API Management security features") | |  |  |  |
| [Backend circuit breaking](labs/backend-circuit-breaking/backend-circuit-breaking.ipynb) | [⭐](#%EF%B8%8F-well-architected-framework "Zero trust, keyless approach with manage identities and Azure API Management security features") | [⭐](#%EF%B8%8F-well-architected-framework "Controls the availability of the OpenAI endpoint with the circuit breaker feature") |  |  |  |
| [Backend pool load balancing](labs/backend-pool-load-balancing/backend-pool-load-balancing.ipynb)  |[⭐](#%EF%B8%8F-well-architected-framework "Zero trust, keyless approach with manage identities and Azure API Management security features")|[⭐](#%EF%B8%8F-well-architected-framework "To ensure resilience, the request is distributed to two or more endpoints with the built-in feature")|[⭐](#%EF%B8%8F-well-architected-framework "Load balances the requests to increase performance with the built-in feature")|  |  |
| [Advanced load balancing](labs/advanced-load-balancing/advanced-load-balancing.ipynb) |[⭐](#%EF%B8%8F-well-architected-framework "Zero trust, keyless approach with manage identities and Azure API Management security features")|[⭐](#%EF%B8%8F-well-architected-framework "To ensure resilience, the request is distributed to two or more endpoints with a custom policy")|[⭐](#%EF%B8%8F-well-architected-framework "Load balances the requests to increase performance with a custom policy")|  |  |
| [Response streaming](labs/response-streaming/response-streaming.ipynb)  |[⭐](#%EF%B8%8F-well-architected-framework "Zero trust, keyless approach with manage identities and Azure API Management security features")| |[⭐](#%EF%B8%8F-well-architected-framework "To get responses sooner, you can 'stream' the completion as it's being generated")|  |  |
| [Vector searching](labs/vector-searching/vector-searching.ipynb) |[⭐](#%EF%B8%8F-well-architected-framework "Zero trust, keyless approach with manage identities and Azure API Management security features")|[⭐](#%EF%B8%8F-well-architected-framework "To ensure resilience, the request is distributed to two or more endpoints with the built-in feature")| [⭐](#%EF%B8%8F-well-architected-framework "Load balances the requests to increase performance with the built-in feature")| |  |
| [Built-in logging](labs/built-in-logging/built-in-logging.ipynb) |[⭐](#%EF%B8%8F-well-architected-framework "Zero trust, keyless approach with manage identities and Azure API Management security features")|[⭐](#%EF%B8%8F-well-architected-framework "To ensure resilience, the request is distributed to two or more endpoints with the built-in feature")|[⭐](#%EF%B8%8F-well-architected-framework "Load balances the requests to increase performance with the built-in feature")|[⭐](#%EF%B8%8F-well-architected-framework "Requests are logged to enable monitoring, alerting and automatic remediation")|[⭐](#%EF%B8%8F-well-architected-framework "Relation between Azure API Management subscription and token consumption allows cost control")|
| [SLM self-hosting](labs/slm-self-hosting/slm-self-hosting.ipynb) |[⭐](#%EF%B8%8F-well-architected-framework "Self hosting the model might improve the security posture with network restrictions") | | [⭐](#%EF%B8%8F-well-architected-framework "Performance might be improved with full control to the self-hosted model") | | |

> [!TIP]
> Check the [Azure Well-Architected Framework perspective on Azure OpenAI Service](https://learn.microsoft.com/azure/well-architected/service-guides/azure-openai) for aditional guidance.

## 🎒 Show and tell

> [!TIP]
> Install the [VS Code Reveal extension](https://marketplace.visualstudio.com/items?itemName=evilz.vscode-reveal), open AI-GATEWAY.md and click on 'slides' at the botton to present the AI Gateway without leaving VS Code.
> Or just open the [AI-GATEWAY.pptx](https://view.officeapps.live.com/op/view.aspx?src=https%3A%2F%2Fraw.githubusercontent.com%2FAzure-Samples%2FAI-Gateway%2Fmain%2FAI-GATEWAY.pptx&wdOrigin=BROWSELINK) for a plain old PowerPoint experience.

## 🥇 Other resources

Numerous reference architectures, best practices and starter kits are available on this topic. Please refer to the resources provided if you need comprehensive solutions or a landing zone to initiate your project. We suggest leveraging the AI-Gateway labs to discover additional capabilities that can be integrated into the reference architectures.

* [GenAI Gateway Guide](https://aka.ms/genai-gateway)
* [Azure OpenAI + APIM Sample](https://aka.ms/apim/genai/sample-app)
* [AI+API better together: Benefits & Best Practices using APIs for AI workloads](https://techcommunity.microsoft.com/t5/apps-on-azure-blog/ai-api-better-together-benefits-amp-best-practices-using-apis/ba-p/4157120)
* [Designing and implementing a gateway solution with Azure OpenAI resources](https://aka.ms/genai-gateway)
* [Azure OpenAI Using PTUs/TPMs With API Management - Using the Scaling Special Sauce](https://github.com/Azure/aoai-apim)
* [Manage Azure OpenAI using APIM](https://github.com/microsoft/AzureOpenAI-with-APIM)
* [Setting up Azure OpenAI as a central capability with Azure API Management](https://github.com/Azure/enterprise-azureai)
* [Introduction to Building AI Apps](https://github.com/Azure/intro-to-intelligent-apps)

> We believe that there may be valuable content that we are currently unaware of. We would greatly appreciate any suggestions or recommendations to enhance this list.

### 🌐 WW GBB initiative

![GBB](images/gbb.png)

### Disclaimer

> [!IMPORTANT]
> This software is provided for demonstration purposes only. It is not intended to be relied upon for any purpose. The creators of this software make no representations or warranties of any kind, express or implied, about the completeness, accuracy, reliability, suitability or availability with respect to the software or the information, products, services, or related graphics contained in the software for any purpose. Any reliance you place on such information is therefore strictly at your own risk.
