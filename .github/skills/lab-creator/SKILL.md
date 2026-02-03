---
name: lab-creator
description: Guide for creating new AI Gateway labs. Use when users want to create a new lab in the labs/ folder. This skill provides the standard lab structure, templates, and patterns used across the AI Gateway repository including Jupyter notebooks, Bicep infrastructure templates, APIM policies, and README documentation.
---

# Lab Creator

This skill provides guidance for creating new labs in the AI Gateway repository.

## Lab Structure

Every lab follows a consistent structure under `labs/<lab-name>/`:

```
labs/<lab-name>/
├── <lab-name>.ipynb          # Main Jupyter notebook (required)
├── main.bicep                # Azure Bicep deployment template (required)
├── policy.xml                # Azure API Management policy (required)
├── README.md                 # Lab documentation (required)
├── clean-up-resources.ipynb  # Cleanup notebook (required)
├── params.json               # Auto-generated, not committed
└── src/                      # Supporting source code (optional)
```

## Creating a New Lab

### Step 1: Create Lab Directory

Create a new folder under `labs/` with a descriptive kebab-case name:
```
labs/<your-lab-name>/
```

### Step 2: Create the Main Jupyter Notebook

Create `<lab-name>.ipynb` with these standard sections:

#### Header Cell (Markdown)
```markdown
# APIM ❤️ Microsoft Foundry

## <Lab Title> lab
![flow](../../images/<lab-name>.gif)

<Brief description of what this lab demonstrates>

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

▶️ Click `Run All` to execute all steps sequentially, or execute them `Step by Step`...
```

#### Section 0: Initialize Variables (Python)
```python
import os, sys, json
sys.path.insert(1, '../../shared')  # add the shared directory to the Python path
import utils

deployment_name = os.path.basename(os.path.dirname(globals()['__vsc_ipynb_file__']))
resource_group_name = f"lab-{deployment_name}"
resource_group_location = "westeurope"

# AI Services configuration
aiservices_config = [{"name": "foundry1", "location": "swedencentral"},
                     {"name": "foundry2", "location": "eastus2"}]

# Models configuration - adjust based on lab requirements
models_config = [{"name": "gpt-4.1-mini", "publisher": "OpenAI", "version": "2025-04-14", "sku": "GlobalStandard", "capacity": 100}]

# APIM configuration
apim_sku = 'Basicv2'
apim_subscriptions_config = [{"name": "subscription1", "displayName": "Subscription 1"}]

# API configuration
inference_api_path = "inference"
inference_api_type = "AzureOpenAIV1"  # options: AzureOpenAI, AzureAI, OpenAI, PassThrough
inference_api_version = "v1"
foundry_project_name = deployment_name

utils.print_ok('Notebook initialized')
```

#### Section 1: Verify Azure CLI (Markdown + Python)
```markdown
<a id='1'></a>
### 1️⃣ Verify the Azure CLI and the connected Azure subscription

The following commands ensure that you have the latest version of the Azure CLI and that the Azure CLI is connected to your Azure subscription.
```

```python
output = utils.run("az account show", "Retrieved az account", "Failed to get the current az account")

if output.success and output.json_data:
    current_user = output.json_data['user']['name']
    tenant_id = output.json_data['tenantId']
    subscription_id = output.json_data['id']

    utils.print_info(f"Current user: {current_user}")
    utils.print_info(f"Tenant ID: {tenant_id}")
    utils.print_info(f"Subscription ID: {subscription_id}")
```

#### Section 2: Create Deployment (Markdown + Python)
```markdown
<a id='2'></a>
### 2️⃣ Create deployment using 🦾 Bicep

This lab uses [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview?tabs=bicep) to declarative define all the resources that will be deployed in the specified resource group. Change the parameters or the [main.bicep](main.bicep) directly to try different configurations.
```

```python
# Create the resource group if doesn't exist
utils.create_resource_group(resource_group_name, resource_group_location)

# Define the Bicep parameters
bicep_parameters = {
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "apimSku": { "value": apim_sku },
        "aiServicesConfig": { "value": aiservices_config },
        "modelsConfig": { "value": models_config },
        "apimSubscriptionsConfig": { "value": apim_subscriptions_config },
        "inferenceAPIPath": { "value": inference_api_path },
        "inferenceAPIType": { "value": inference_api_type },
        "foundryProjectName": { "value": foundry_project_name },
    }
}

# Write the parameters to the params.json file
with open('params.json', 'w') as bicep_parameters_file:
    bicep_parameters_file.write(json.dumps(bicep_parameters))

# Run the deployment
output = utils.run(f"az deployment group create --name {deployment_name} --resource-group {resource_group_name} --template-file main.bicep --parameters params.json",
    f"Deployment '{deployment_name}' succeeded", f"Deployment '{deployment_name}' failed")
```

#### Section 3: Get Deployment Outputs (Markdown + Python)
```markdown
<a id='3'></a>
### 3️⃣ Get the deployment outputs

We are now at the stage where we only need to retrieve the gateway URL and the subscription before we are ready for testing.
```

```python
# Obtain all of the outputs from the deployment
output = utils.run(f"az deployment group show --name {deployment_name} -g {resource_group_name}", f"Retrieved deployment: {deployment_name}", f"Failed to retrieve deployment: {deployment_name}")

if output.success and output.json_data:
    log_analytics_id = utils.get_deployment_output(output, 'logAnalyticsWorkspaceId', 'Log Analytics Id')
    apim_service_id = utils.get_deployment_output(output, 'apimServiceId', 'APIM Service Id')
    apim_resource_gateway_url = utils.get_deployment_output(output, 'apimResourceGatewayURL', 'APIM API Gateway URL')
    apim_subscriptions = json.loads(utils.get_deployment_output(output, 'apimSubscriptions').replace("\'", "\""))
    for subscription in apim_subscriptions:
        subscription_name = subscription['name']
        subscription_key = subscription['key']
        utils.print_info(f"Subscription Name: {subscription_name}")
        utils.print_info(f"Subscription Key: ****{subscription_key[-4:]}")
    api_key = apim_subscriptions[0].get("key")
```

#### Test Section (Markdown + Python)
```markdown
<a id='requests'></a>
### 🧪 Test the API using a direct HTTP call

Tip: Use the [tracing tool](../../tools/tracing.ipynb) to track the behavior and troubleshoot the [policy](policy.xml).
```

Add your lab-specific test code here.

#### Cleanup Section (Markdown)
```markdown
<a id='clean'></a>
### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
```

### Step 3: Create the Bicep Template

Create `main.bicep` with this standard structure:

```bicep
// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference'
param foundryProjectName string = 'default'

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawModule.outputs.id
    customMetricsOptedInType: 'WithDimensions'
  }
}

// 3. API Management
module apimModule '../../modules/apim/v3/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 4. AI Foundry
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
  name: 'foundryModule'
  params: {
    aiServicesConfig: aiServicesConfig
    modelsConfig: modelsConfig
    apimPrincipalId: apimModule.outputs.principalId
    foundryProjectName: foundryProjectName
  }
}

// 5. APIM Inference API
module inferenceAPIModule '../../modules/apim/v3/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
```

### Step 4: Create the APIM Policy

Create `policy.xml` with the base structure:

```xml
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="{backend-id}" />
        <!-- Add your custom inbound policies here -->
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        <!-- Add your custom outbound policies here -->
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

### Step 5: Create the README

Create `README.md` with this structure:

```markdown
---
name: "<Lab Display Name>"
architectureDiagram: images/<lab-name>.gif
categories: ["<Category>"]
services: ["Azure AI Foundry", "Azure OpenAI"]
shortDescription: "<One-line description>"
detailedDescription: "<Detailed description of what the lab demonstrates>"
authors: ["<github-username>"]
---

# APIM ❤️ AI Foundry

## [<Lab Title> lab](<lab-name>.ipynb)

[![flow](../../images/<lab-name>.gif)](<lab-name>.ipynb)

<Description of what this lab demonstrates and its key features>

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](<lab-name>.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
```

### Step 6: Create the Cleanup Notebook

Create `clean-up-resources.ipynb` with these cells:

#### Markdown Cell
```markdown
### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
```

#### Python Cell
```python
import os, sys
sys.path.insert(1, '../../shared')  # add the shared directory to the Python path
import utils

deployment_name = os.path.basename(os.path.dirname(globals()['__vsc_ipynb_file__']))
resource_group = f"lab-{deployment_name}"

utils.cleanup_resources(deployment_name, resource_group_name=resource_group)
```

## Available Bicep Modules

Reference these modules from `../../modules/`:

| Module Path | Purpose |
|-------------|---------|
| `apim/v3/apim.bicep` | Azure API Management instance |
| `apim/v3/inference-api.bicep` | APIM Inference API configuration |
| `apim-streamable-mcp/` | APIM with MCP streaming support |
| `cognitive-services/v3/foundry.bicep` | AI Foundry with model deployments |
| `operational-insights/v1/workspaces.bicep` | Log Analytics Workspace |
| `monitor/v1/appinsights.bicep` | Application Insights |
| `network/` | Networking infrastructure |
| `apic/v1/` | Azure API Center |

## Shared Utilities

Import the shared utilities in notebooks:

```python
import os, sys, json
sys.path.insert(1, '../../shared')
import utils
```

Key functions from `utils.py`:
- `utils.run(command, success_msg, error_msg)` - Execute Azure CLI commands
- `utils.print_ok(msg)`, `utils.print_error(msg)`, `utils.print_info(msg)` - Formatted output
- `utils.create_resource_group(name, location)` - Create Azure resource group
- `utils.get_deployment_output(output, key, label)` - Extract Bicep outputs
- `utils.cleanup_resources(deployment, resource_group_name)` - Delete resources

## Lab Categories

When creating a lab, assign it to one of these categories in the README frontmatter:

- `AI Agents & MCP` - Model Context Protocol, agents, agentic workflows
- `Model Integration` - Third-party models, AI Foundry SDK
- `Load Balancing & Routing` - Backend pools, model routing
- `Security & Access Control` - Authentication, content safety
- `Monitoring & Logging` - Tracing, metrics, logging
- `Rate Limiting & Caching` - Token limits, semantic caching
- `Specialized Features` - Realtime API, images, functions
- `Operations` - FinOps, production deployment
