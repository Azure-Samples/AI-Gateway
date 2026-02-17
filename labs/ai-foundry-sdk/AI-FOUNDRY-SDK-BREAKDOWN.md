# Azure AI Foundry SDK Code Breakdown

This document provides a detailed breakdown of the Python code used in the `ai-foundry-sdk.ipynb` notebook, explaining the Azure AI Foundry SDK syntax and patterns.

---

## Table of Contents

1. [Notebook Initialization](#1-notebook-initialization)
2. [Azure CLI Verification](#2-azure-cli-verification)
3. [Bicep Deployment](#3-bicep-deployment)
4. [Retrieving Deployment Outputs](#4-retrieving-deployment-outputs)
5. [Chat Completion with AI Foundry SDK](#5-chat-completion-with-ai-foundry-sdk)
6. [Chat Completion with APIM](#6-chat-completion-with-apim)

---

## 1. Notebook Initialization

```python
import os, sys, json
sys.path.insert(1, '../../shared')  # add the shared directory to the Python path
import utils
```

### What's Happening:
- **`import os, sys, json`**: Imports standard Python libraries for OS operations, system configuration, and JSON handling.
- **`sys.path.insert(1, '../../shared')`**: Adds the `shared` directory to Python's module search path, allowing imports from that location.
- **`import utils`**: Imports the custom utility module from the shared directory containing helper functions for Azure operations.

### Configuration Variables:

```python
deployment_name = os.path.basename(os.path.dirname(globals()['__vsc_ipynb_file__']))
resource_group_name = f"lab-{deployment_name}"
resource_group_location = "eastus2"
```

| Variable | Purpose |
|----------|---------|
| `deployment_name` | Extracts the folder name (e.g., `ai-foundry-sdk`) to use as deployment identifier |
| `resource_group_name` | Creates a resource group name prefixed with `lab-` |
| `resource_group_location` | Azure region where resources will be deployed |

### AI Services Configuration:

```python
aiservices_config = [{"name": "foundry1", "location": "eastus2"}]
```

This defines a list of AI Services accounts to create. Each entry specifies:
- **`name`**: Unique identifier for the AI service instance
- **`location`**: Azure region for the service

### Models Configuration:

```python
models_config = [{"name": "gpt-4.1-mini", "publisher": "OpenAI", "version": "2025-04-14", "sku": "GlobalStandard", "capacity": 20}]
```

| Property | Description |
|----------|-------------|
| `name` | Model deployment name (e.g., `gpt-4.1-mini`) |
| `publisher` | Model publisher (e.g., `OpenAI`) |
| `version` | Specific model version |
| `sku` | Deployment tier (`GlobalStandard`, `Standard`, etc.) |
| `capacity` | Tokens-per-minute capacity in thousands |

### APIM Configuration:

```python
apim_sku = 'Basicv2'
apim_subscriptions_config = [{"name": "subscription1", "displayName": "Subscription 1"}]
```

- **`apim_sku`**: Azure API Management pricing tier (Basicv2 is cost-effective for labs)
- **`apim_subscriptions_config`**: List of APIM subscriptions for API access control

### Inference API Settings:

```python
inference_api_path = "inference"        # URL path segment for the inference API
inference_api_type = "AzureAI"          # API type: AzureOpenAI, AzureAI, OpenAI, PassThrough
inference_api_version = "2024-05-01-preview"
foundry_project_name = deployment_name
```

---

## 2. Azure CLI Verification

```python
output = utils.run("az account show", "Retrieved az account", "Failed to get the current az account")

if output.success and output.json_data:
    current_user = output.json_data['user']['name']
    tenant_id = output.json_data['tenantId']
    subscription_id = output.json_data['id']
```

### What's Happening:
- **`utils.run()`**: Executes an Azure CLI command and returns a result object
  - First param: The CLI command to execute
  - Second param: Success message
  - Third param: Failure message
- **`output.success`**: Boolean indicating command success
- **`output.json_data`**: Parsed JSON response from the CLI command

### Extracting Account Information:
The code extracts key values from the `az account show` JSON response:
- `user.name`: Current logged-in user
- `tenantId`: Azure AD tenant ID
- `id`: Azure subscription ID

---

## 3. Bicep Deployment

```python
# Create the resource group if doesn't exist
utils.create_resource_group(resource_group_name, resource_group_location)
```

This utility function wraps `az group create` to ensure the resource group exists.

### Building Bicep Parameters:

```python
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
        "foundryProjectName": { "value": foundry_project_name }
    }
}
```

### Parameter File Structure:
| Field | Purpose |
|-------|---------|
| `$schema` | ARM template schema reference |
| `contentVersion` | Version identifier for the parameters file |
| `parameters` | Dictionary of parameter name → `{ "value": ... }` pairs |

### Writing & Executing Deployment:

```python
with open('params.json', 'w') as bicep_parameters_file:
    bicep_parameters_file.write(json.dumps(bicep_parameters))

output = utils.run(f"az deployment group create --name {deployment_name} --resource-group {resource_group_name} --template-file main.bicep --parameters params.json",
    f"Deployment '{deployment_name}' succeeded", f"Deployment '{deployment_name}' failed")
```

The `az deployment group create` command:
- `--name`: Deployment name for tracking
- `--resource-group`: Target resource group
- `--template-file`: Path to Bicep template
- `--parameters`: Path to parameters JSON file

---

## 4. Retrieving Deployment Outputs

```python
output = utils.run(f"az deployment group show --name {deployment_name} -g {resource_group_name}", 
    f"Retrieved deployment: {deployment_name}", 
    f"Failed to retrieve deployment: {deployment_name}")

if output.success and output.json_data:
    log_analytics_id = utils.get_deployment_output(output, 'logAnalyticsWorkspaceId', 'Log Analytics Id')
    apim_service_id = utils.get_deployment_output(output, 'apimServiceId', 'APIM Service Id')
    apim_resource_gateway_url = utils.get_deployment_output(output, 'apimResourceGatewayURL', 'APIM API Gateway URL')
```

### What's Happening:
- **`az deployment group show`**: Retrieves details of a completed deployment
- **`utils.get_deployment_output()`**: Helper to extract specific output values from the deployment

### Parsing Subscriptions:

```python
apim_subscriptions = json.loads(utils.get_deployment_output(output, 'apimSubscriptions').replace("\'", "\""))
for subscription in apim_subscriptions:
    subscription_name = subscription['name']
    subscription_key = subscription['key']
```

The subscription data is returned as a string representation of a list, so:
1. Replace single quotes with double quotes for valid JSON
2. Parse with `json.loads()`
3. Iterate to extract name and key for each subscription

---

## 5. Chat Completion with AI Foundry SDK

This is the **core AI Foundry SDK usage pattern**.

### Imports:

```python
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
```

| Import | Purpose |
|--------|---------|
| `DefaultAzureCredential` | Provides automatic authentication using available credentials (Azure CLI, managed identity, environment variables, etc.) |
| `AIProjectClient` | Main client for interacting with Azure AI Foundry projects |

### Creating the Project Client:

```python
project = AIProjectClient(
  endpoint=foundry_project_endpoint,
  credential=DefaultAzureCredential()
)
```

| Parameter | Description |
|-----------|-------------|
| `endpoint` | The AI Foundry project endpoint URL (e.g., `https://<project>.services.ai.azure.com`) |
| `credential` | Authentication credential object |

### Getting the OpenAI Client:

```python
models = project.inference.get_azure_openai_client(api_version=inference_api_version)
```

This method returns an `AzureOpenAI` client from the `openai` package, pre-configured with:
- The project's endpoint
- Proper authentication
- Specified API version

### Making a Chat Completion Request:

```python
response = models.chat.completions.create(
    model=str(models_config[0].get('name')),
    messages=[
      {"role": "system", "content": "You are a sarcastic, unhelpful assistant."},
      {"role": "user", "content": "Can you tell me the time, please?"}
    ],
)
```

### Chat Completion Parameters:

| Parameter | Description |
|-----------|-------------|
| `model` | Name of the deployed model (e.g., `gpt-4.1-mini`) |
| `messages` | List of message objects with `role` and `content` |

### Message Roles:

| Role | Purpose |
|------|---------|
| `system` | Sets the assistant's behavior and personality |
| `user` | Contains the user's input/question |
| `assistant` | (not shown) Previous assistant responses for multi-turn conversations |

### Accessing the Response:

```python
print("💬 ", response.choices[0].message.content)
```

The response structure:
- `response.choices`: List of completion choices (usually 1)
- `response.choices[0].message`: The message object
- `response.choices[0].message.content`: The actual text response

---

## 6. Chat Completion with APIM

This demonstrates using the **Azure AI Inference SDK** to call models through API Management.

### Imports:

```python
from azure.ai.inference import ChatCompletionsClient
from azure.core.credentials import AzureKeyCredential
from azure.ai.inference.models import SystemMessage, UserMessage
```

| Import | Purpose |
|--------|---------|
| `ChatCompletionsClient` | Client specifically for chat completion operations |
| `AzureKeyCredential` | Credential wrapper for API key authentication |
| `SystemMessage`, `UserMessage` | Typed message classes for better code clarity |

### Creating the Client:

```python
client = ChatCompletionsClient(
    endpoint=f"{apim_resource_gateway_url}/{inference_api_path}/models",
    credential=AzureKeyCredential(api_key),
)
```

| Parameter | Description |
|-----------|-------------|
| `endpoint` | APIM gateway URL with the inference API path (e.g., `https://<apim>.azure-api.net/inference/models`) |
| `credential` | APIM subscription key wrapped in `AzureKeyCredential` |

### Making a Request:

```python
response = client.complete(
    messages=[
        SystemMessage(content="You are a sarcastic, unhelpful assistant."),
        UserMessage(content="Can you tell me the time, please?"),
    ],
    model=str(models_config[0].get('name'))
)
```

### Key Differences from Direct AI Foundry Usage:

| Aspect | AI Foundry Direct | APIM Route |
|--------|-------------------|------------|
| Authentication | `DefaultAzureCredential` (Azure AD) | `AzureKeyCredential` (API key) |
| Client | `AIProjectClient` → OpenAI client | `ChatCompletionsClient` |
| Message format | Dictionaries | Typed message classes |
| Endpoint | Project endpoint | APIM gateway URL |

---

## Summary of SDK Patterns

### Authentication Options:

1. **DefaultAzureCredential** - Best for Azure-native apps with Azure AD
   ```python
   from azure.identity import DefaultAzureCredential
   credential = DefaultAzureCredential()
   ```

2. **AzureKeyCredential** - Best for API key-based access
   ```python
   from azure.core.credentials import AzureKeyCredential
   credential = AzureKeyCredential("your-api-key")
   ```

### Client Hierarchy:

```
AIProjectClient (azure.ai.projects)
└── inference
    └── get_azure_openai_client() → AzureOpenAI client
        └── chat.completions.create()
```

### Required Packages:

```bash
pip install azure-ai-projects azure-ai-inference azure-identity
```

---

## Additional Resources

- [Azure AI Foundry SDK Overview](https://learn.microsoft.com/azure/ai-studio/how-to/develop/sdk-overview)
- [Azure AI Inference SDK](https://learn.microsoft.com/python/api/overview/azure/ai-inference-readme)
- [Azure Identity Library](https://learn.microsoft.com/python/api/overview/azure/identity-readme)
