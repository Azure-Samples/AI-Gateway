---
name: "Microsoft Foundry End-to-End Private with APIM AI Gateway"
architectureDiagram: images/foundry-e2e-private.gif
categories:
  - Security & Access Control
  - AI Agents
services:
  - Azure AI Foundry
  - Azure API Management
  - Azure OpenAI
  - Private Link
  - Azure Bastion
  - Application Insights
shortDescription: "End-to-end private Microsoft Foundry deployment fronted by APIM as the AI Gateway, with cross-region OpenAI."
detailedDescription: "Deploy Microsoft Foundry, its standard backend resources (Azure AI Search, Cosmos DB, Storage), Azure API Management (StandardV2) and a cross-region Azure OpenAI account into a single private VNet. APIM acts as the AI Gateway: it terminates a private endpoint, integrates outbound into the VNet, imports the Azure OpenAI inference API, and authenticates to Foundry / OpenAI using its system-assigned managed identity. The Foundry project receives APIM gateway connections so agents can call models as `apim-gateway/<model>` (primary) or `apim-gateway-crossregion/<model>` (secondary region). Application Insights is wired into the project for agent tracing and an Azure Bastion + Windows jump-box VM are included for testing the private setup from inside the VNet."
authors:
  - duongthaiha
---

# APIM ❤️ Microsoft Foundry

## [End-to-End Private Lab](foundry-e2e-private.ipynb)

![architecture](images/foundry-e2e-private.gif)

> The architecture diagram above is a placeholder — replace `images/foundry-e2e-private.gif` with the lab diagram.

This lab demonstrates an **end-to-end private** Microsoft Foundry deployment fronted by Azure API Management (StandardV2) acting as the AI Gateway. Every backend service — Foundry, AI Search, Cosmos DB, Storage, the cross-region Azure OpenAI account and APIM itself — runs behind private endpoints in a single VNet. A jump-box VM accessible via Azure Bastion is included so you can test the private endpoints from inside the VNet.

## 🏗️ Architecture

Core flow: **Agent → Data Proxy (private agent subnet) → APIM private endpoint → APIM → Foundry / OpenAI private endpoint**

Components:

- **Microsoft Foundry account + project** with `networkInjections` to a dedicated agent subnet so the Foundry Data Proxy can reach private backends.
- **AI Search, Cosmos DB, Storage** behind private endpoints with private DNS zones (`privatelink.search.windows.net`, `privatelink.documents.azure.com`, `privatelink.blob.core.windows.net`, …).
- **Azure API Management** `StandardV2` with outbound VNet integration into the `apim-subnet` and an inbound private endpoint in the `pe-subnet`.
- **Azure OpenAI inference API** imported into APIM. The inbound policy ([policy.xml](policy.xml)) uses `authentication-managed-identity` to obtain a token for `https://cognitiveservices.azure.com/` and sets it as `Authorization: Bearer …` on the upstream call.
- **APIM gateway connection** on the Foundry project (default name `apim-gateway`). Agents call models as `apim-gateway/<model-name>`.
- **Cross-region Azure OpenAI account** in a secondary region with a private endpoint into the primary VNet, exposed through APIM as `apim-gateway-crossregion/<model-name>`.
- **Application Insights + Log Analytics**, connected to the Foundry project for agent tracing.
- **Azure Bastion + Windows jump-box VM** for testing the private deployment from inside the VNet.

## ✨ Key features

- Single Bicep template that wires the full private-by-default topology end to end.
- Two AI Gateway connections on the Foundry project: primary region (`apim-gateway/<model>`) and cross-region (`apim-gateway-crossregion/<model>`).
- Managed-identity authentication from APIM to Foundry / OpenAI — no API keys in flight.
- Private DNS, private endpoints, and `publicNetworkAccess: Disabled` on the Foundry account and cross-region OpenAI — no public traffic reaches the AI services.
- Optional Bastion + jump-box VM toggled by parameter.
- Optional auto-approval of the AI Search → Foundry shared private link via a Bicep `deploymentScript`. **Disabled by default**, because `Microsoft.Resources/deploymentScripts` requires shared-key access on its backing storage account and is therefore blocked in tenants that enforce `KeyBasedAuthenticationNotPermitted`. Set `autoApproveSharedPrivateLink: true` if your tenant allows it; otherwise the notebook approves the SPL with a single `az network private-endpoint-connection approve` call.

## 📋 Prerequisites

- [Python 3.12 or later](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) with the [Jupyter extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and signed in
- An Azure subscription with `Contributor` permissions
- Quota for the chosen models in **both** the primary location (default `eastus2`, `gpt-4o-mini`) and the cross-region location (default `swedencentral`, `gpt-4o`)

## 🚀 Get started

Open the [Jupyter notebook](foundry-e2e-private.ipynb) and run the cells in order:

1. Initialize variables (model, regions, jump-box password, etc.)
2. Verify the Azure CLI subscription
3. Create the resource group and deploy `main.bicep` — **this takes ~30-45 minutes** because of APIM `StandardV2` provisioning + VNet integration
4. Capture the deployment outputs (project endpoint, APIM gateway URL, App Insights connection string, jump-box name, etc.)

## 🧪 Testing

Because the Foundry project is **private**, the test snippets need to run from inside the VNet (or from a peered network). The notebook walks through:

- Section 4 — using `azure-ai-projects` from the jump-box to create an agent with `model="apim-gateway/<model-name>"` and run a chat
- Section 5 — same pattern for the cross-region connection (`model="apim-gateway-crossregion/<model-name>"`)
- Section 6 — connecting to the jump-box via Azure Bastion (CLI `az network bastion rdp` or the Portal)

## 🗑️ Cleanup

When you are finished with the lab, run the [clean-up notebook](clean-up-resources.ipynb) — this deletes the entire resource group, including Bastion, VMs, private endpoints, and the StandardV2 APIM instance.

## 📚 Additional resources

- [Microsoft Foundry agents — AI Gateway pattern](https://learn.microsoft.com/azure/foundry/agents/how-to/ai-gateway)
- [Azure API Management private endpoints](https://learn.microsoft.com/azure/api-management/private-endpoint)
- [Azure API Management VNet integration (StandardV2)](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound)
- [Reference Bicep template (foundry-samples 19-hybrid-private-resources-agent-setup)](https://github.com/azure-ai-foundry/foundry-samples)
