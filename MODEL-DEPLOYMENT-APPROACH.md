# Model Deployment Approach for Azure AI Foundry

This document outlines the recommended approach for deploying, modifying, and deleting model deployments in Azure AI Foundry, and how this differs from agent deployment.

---

## Table of Contents

1. [Model Deployments vs Agents](#1-model-deployments-vs-agents)
2. [Recommendation: IaC for Model Deployments](#2-recommendation-iac-for-model-deployments)
3. [Bicep Approach (Recommended)](#3-bicep-approach-recommended)
4. [Terraform Approach](#4-terraform-approach)
5. [Python SDK Approach](#5-python-sdk-approach)
6. [Azure CLI Approach](#6-azure-cli-approach)
7. [Layered Deployment Architecture](#7-layered-deployment-architecture)
8. [Two-Pipeline Strategy](#8-two-pipeline-strategy)
9. [Common Operations](#9-common-operations)
10. [Summary](#10-summary)

---

## 1. Model Deployments vs Agents

Model deployments and agents are fundamentally different types of resources:

| Aspect | Model Deployments | Agents |
|--------|-------------------|--------|
| **What they are** | Infrastructure resources (compute, endpoints) | Application configurations |
| **Change frequency** | Infrequent (weeks/months) | Frequent (days/weeks) |
| **Azure Resource** | ✅ Yes - first-class ARM resource | ❌ No - not an ARM resource |
| **Bicep/Terraform support** | ✅ Native support | ❌ Not supported |
| **Deployment time** | Minutes (provisioning compute) | Seconds |
| **Shared across** | Multiple agents | Single agent |
| **Requires quota** | ✅ Yes - TPM/RPM limits | ❌ No |
| **Cost implications** | ✅ Direct cost based on capacity | ❌ No direct cost |

### Key Insight

> **Model deployments are infrastructure; agents are applications.**
> 
> They should be deployed accordingly with separate pipelines and tooling.

---

## 2. Recommendation: IaC for Model Deployments

Model deployments should be managed via **Bicep or Terraform**, not Python SDK or manifest approach, because:

1. **They're real Azure resources** with proper resource types:
   - `Microsoft.CognitiveServices/accounts/deployments`
   - `Microsoft.MachineLearningServices/workspaces/deployments`

2. **They integrate with Azure resource management**:
   - Quotas and capacity limits
   - Role-based access control (RBAC)
   - Cost management and billing
   - Azure Policy compliance

3. **They change infrequently**:
   - Model version upgrades are planned events
   - Capacity changes require quota approval
   - New model types require evaluation

4. **They're shared infrastructure**:
   - Multiple agents reference the same deployment
   - Changes affect all dependent agents

---

## 3. Bicep Approach (Recommended)

### Basic Model Deployment

```bicep
// modules/model-deployments.bicep

@description('Name of the Azure AI Services account')
param aiServicesName string

@description('Model deployments to create')
param modelDeployments array = [
  {
    name: 'gpt-4o'
    model: 'gpt-4o'
    version: '2024-08-06'
    sku: 'GlobalStandard'
    capacity: 50
  }
  {
    name: 'gpt-4o-mini'
    model: 'gpt-4o-mini'
    version: '2024-07-18'
    sku: 'GlobalStandard'
    capacity: 100
  }
]

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiServicesName
}

resource deployments 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for deployment in modelDeployments: {
  parent: aiServices
  name: deployment.name
  sku: {
    name: deployment.sku
    capacity: deployment.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: deployment.model
      version: deployment.version
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}]

output deploymentNames array = [for (deployment, i) in modelDeployments: deployments[i].name]
```

### Complete AI Services with Deployments

```bicep
// main.bicep

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Model configuration')
param modelsConfig array = [
  {
    name: 'gpt-4o'
    model: 'gpt-4o'
    version: '2024-08-06'
    sku: 'GlobalStandard'
    capacity: environment == 'prod' ? 100 : 30
  }
  {
    name: 'gpt-4o-mini'
    model: 'gpt-4o-mini'
    version: '2024-07-18'
    sku: 'GlobalStandard'
    capacity: environment == 'prod' ? 200 : 50
  }
]

// AI Services Account
resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'ai-services-${environment}-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: 'ai-services-${environment}-${uniqueString(resourceGroup().id)}'
    publicNetworkAccess: 'Enabled'
  }
}

// Model Deployments
resource modelDeployments 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for model in modelsConfig: {
  parent: aiServices
  name: model.name
  sku: {
    name: model.sku
    capacity: model.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: model.model
      version: model.version
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}]

// Outputs for downstream use (agent deployments)
output aiServicesEndpoint string = aiServices.properties.endpoint
output aiServicesName string = aiServices.name
output modelDeploymentNames array = [for (model, i) in modelsConfig: modelDeployments[i].name]
```

### Environment-Specific Parameters

```json
// parameters/dev.parameters.json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "dev" },
    "modelsConfig": {
      "value": [
        {
          "name": "gpt-4o",
          "model": "gpt-4o",
          "version": "2024-08-06",
          "sku": "GlobalStandard",
          "capacity": 30
        }
      ]
    }
  }
}
```

```json
// parameters/prod.parameters.json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "prod" },
    "modelsConfig": {
      "value": [
        {
          "name": "gpt-4o",
          "model": "gpt-4o",
          "version": "2024-08-06",
          "sku": "GlobalStandard",
          "capacity": 100
        },
        {
          "name": "gpt-4o-mini",
          "model": "gpt-4o-mini",
          "version": "2024-07-18",
          "sku": "GlobalStandard",
          "capacity": 200
        }
      ]
    }
  }
}
```

---

## 4. Terraform Approach

### Using azurerm Provider

```hcl
# providers.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}
```

```hcl
# variables.tf
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

variable "location" {
  type        = string
  default     = "eastus2"
}

variable "model_deployments" {
  type = list(object({
    name     = string
    model    = string
    version  = string
    sku      = string
    capacity = number
  }))
  description = "List of model deployments to create"
}
```

```hcl
# main.tf
resource "azurerm_resource_group" "main" {
  name     = "rg-ai-${var.environment}"
  location = var.location
}

resource "azurerm_cognitive_account" "ai_services" {
  name                  = "ai-services-${var.environment}-${random_string.suffix.result}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  kind                  = "AIServices"
  sku_name              = "S0"
  custom_subdomain_name = "ai-services-${var.environment}-${random_string.suffix.result}"

  tags = {
    environment = var.environment
  }
}

resource "azurerm_cognitive_deployment" "models" {
  for_each = { for model in var.model_deployments : model.name => model }

  name                 = each.value.name
  cognitive_account_id = azurerm_cognitive_account.ai_services.id

  model {
    format  = "OpenAI"
    name    = each.value.model
    version = each.value.version
  }

  sku {
    name     = each.value.sku
    capacity = each.value.capacity
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
```

```hcl
# outputs.tf
output "ai_services_endpoint" {
  value = azurerm_cognitive_account.ai_services.endpoint
}

output "model_deployment_names" {
  value = [for d in azurerm_cognitive_deployment.models : d.name]
}
```

### Environment-Specific tfvars

```hcl
# environments/dev.tfvars
environment = "dev"
location    = "eastus2"

model_deployments = [
  {
    name     = "gpt-4o"
    model    = "gpt-4o"
    version  = "2024-08-06"
    sku      = "GlobalStandard"
    capacity = 30
  }
]
```

```hcl
# environments/prod.tfvars
environment = "prod"
location    = "eastus2"

model_deployments = [
  {
    name     = "gpt-4o"
    model    = "gpt-4o"
    version  = "2024-08-06"
    sku      = "GlobalStandard"
    capacity = 100
  },
  {
    name     = "gpt-4o-mini"
    model    = "gpt-4o-mini"
    version  = "2024-07-18"
    sku      = "GlobalStandard"
    capacity = 200
  }
]
```

---

## 5. Python SDK Approach

The Python SDK can manage deployments but is better suited for **ad-hoc operations and scripting** rather than production CI/CD.

### Using Azure Management SDK

```python
# model_management.py
from azure.identity import DefaultAzureCredential
from azure.mgmt.cognitiveservices import CognitiveServicesManagementClient
from azure.mgmt.cognitiveservices.models import Deployment, DeploymentModel, Sku

class ModelDeploymentManager:
    def __init__(self, subscription_id: str, resource_group: str, account_name: str):
        self.subscription_id = subscription_id
        self.resource_group = resource_group
        self.account_name = account_name
        self.client = CognitiveServicesManagementClient(
            credential=DefaultAzureCredential(),
            subscription_id=subscription_id
        )
    
    def create_deployment(
        self,
        deployment_name: str,
        model_name: str,
        model_version: str,
        sku_name: str = "GlobalStandard",
        capacity: int = 30
    ) -> Deployment:
        """Create or update a model deployment"""
        deployment = Deployment(
            sku=Sku(name=sku_name, capacity=capacity),
            properties={
                "model": {
                    "format": "OpenAI",
                    "name": model_name,
                    "version": model_version
                },
                "versionUpgradeOption": "OnceNewDefaultVersionAvailable",
                "raiPolicyName": "Microsoft.Default"
            }
        )
        
        result = self.client.deployments.begin_create_or_update(
            resource_group_name=self.resource_group,
            account_name=self.account_name,
            deployment_name=deployment_name,
            deployment=deployment
        ).result()
        
        print(f"✓ Deployment created/updated: {result.name}")
        return result
    
    def list_deployments(self) -> list:
        """List all model deployments"""
        deployments = self.client.deployments.list(
            resource_group_name=self.resource_group,
            account_name=self.account_name
        )
        return list(deployments)
    
    def get_deployment(self, deployment_name: str) -> Deployment:
        """Get a specific deployment"""
        return self.client.deployments.get(
            resource_group_name=self.resource_group,
            account_name=self.account_name,
            deployment_name=deployment_name
        )
    
    def update_capacity(self, deployment_name: str, new_capacity: int) -> Deployment:
        """Update deployment capacity (TPM)"""
        existing = self.get_deployment(deployment_name)
        existing.sku.capacity = new_capacity
        
        result = self.client.deployments.begin_create_or_update(
            resource_group_name=self.resource_group,
            account_name=self.account_name,
            deployment_name=deployment_name,
            deployment=existing
        ).result()
        
        print(f"✓ Capacity updated: {result.name} -> {new_capacity}K TPM")
        return result
    
    def delete_deployment(self, deployment_name: str) -> None:
        """Delete a model deployment"""
        self.client.deployments.begin_delete(
            resource_group_name=self.resource_group,
            account_name=self.account_name,
            deployment_name=deployment_name
        ).result()
        
        print(f"✓ Deployment deleted: {deployment_name}")


# Example usage
if __name__ == "__main__":
    import os
    
    manager = ModelDeploymentManager(
        subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"],
        resource_group="my-rg",
        account_name="my-ai-services"
    )
    
    # Create a deployment
    manager.create_deployment(
        deployment_name="gpt-4o",
        model_name="gpt-4o",
        model_version="2024-08-06",
        capacity=50
    )
    
    # List all deployments
    print("\nCurrent deployments:")
    for d in manager.list_deployments():
        model = d.properties.model
        print(f"  {d.name}: {model.name} v{model.version} ({d.sku.capacity}K TPM)")
    
    # Update capacity
    manager.update_capacity("gpt-4o", 100)
    
    # Delete a deployment
    # manager.delete_deployment("old-deployment")
```

### When to Use Python SDK

| Scenario | Use Python SDK? |
|----------|-----------------|
| Production CI/CD pipeline | ❌ Use Bicep/Terraform |
| One-time capacity adjustment | ✅ Quick script |
| Listing current deployments | ✅ Convenient |
| Emergency changes | ✅ Fast |
| Automation scripts | ✅ Good fit |
| Integration tests | ✅ Verify deployments exist |

---

## 6. Azure CLI Approach

For quick ad-hoc operations:

### Create Deployment

```bash
az cognitiveservices account deployment create \
  --name "my-ai-services" \
  --resource-group "my-rg" \
  --deployment-name "gpt-4o" \
  --model-name "gpt-4o" \
  --model-version "2024-08-06" \
  --model-format "OpenAI" \
  --sku-name "GlobalStandard" \
  --sku-capacity 50
```

### List Deployments

```bash
az cognitiveservices account deployment list \
  --name "my-ai-services" \
  --resource-group "my-rg" \
  --output table
```

### Update Capacity

```bash
az cognitiveservices account deployment create \
  --name "my-ai-services" \
  --resource-group "my-rg" \
  --deployment-name "gpt-4o" \
  --sku-capacity 100
```

### Delete Deployment

```bash
az cognitiveservices account deployment delete \
  --name "my-ai-services" \
  --resource-group "my-rg" \
  --deployment-name "old-deployment"
```

### Show Deployment Details

```bash
az cognitiveservices account deployment show \
  --name "my-ai-services" \
  --resource-group "my-rg" \
  --deployment-name "gpt-4o"
```

---

## 7. Layered Deployment Architecture

Clear separation between infrastructure and application:

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: Infrastructure (Bicep/Terraform)                      │
│  Change frequency: Monthly | Approval: CAB/Change Management    │
│                                                                 │
│  Resources:                                                     │
│  • Azure AI Foundry Hub + Project                               │
│  • Azure AI Services account                                    │
│  • Model Deployments (gpt-4o, gpt-4o-mini, etc.)  ◀── THIS DOC  │
│  • Azure API Management (APIM)                                  │
│  • Connections (Bing, OpenAPI endpoints)                        │
│  • Key Vault, Storage                                           │
│  • Networking (VNet, Private Endpoints)                         │
│  • Log Analytics, Application Insights                          │
│                                                                 │
│  Deployment Method: az deployment group create / terraform apply│
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Outputs: deployment names, endpoints, connection IDs
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: Application (Agent Manifests)                         │
│  Change frequency: Weekly | Approval: Team/PR review            │
│                                                                 │
│  Resources:                                                     │
│  • Agent definitions (name, instructions, tools)                │
│  • Vector stores                                                │
│  • Uploaded files (knowledge base content)                      │
│  • Tool configurations                                          │
│                                                                 │
│  Deployment Method: agent-deploy apply (manifest-based)         │
│  See: AGENT-CICD-APPROACH.md                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Separation?

| Factor | Infrastructure | Application |
|--------|----------------|-------------|
| **Deployment time** | 5-30 minutes | Seconds |
| **Change risk** | High (affects all agents) | Lower (single agent) |
| **Approval process** | CAB/Change control | PR review |
| **Rollback complexity** | Complex | Simple |
| **Skills required** | Platform engineering | Application development |

---

## 8. Two-Pipeline Strategy

### Infrastructure Pipeline (Bicep/Terraform)

```yaml
# .github/workflows/deploy-infrastructure.yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'infra/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options: [dev, staging, prod]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Validate Bicep
        run: az bicep build --file infra/main.bicep

  deploy-dev:
    needs: validate
    if: github.event_name == 'push' || github.event.inputs.environment == 'dev'
    runs-on: ubuntu-latest
    environment: development
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS_DEV }}
      
      - name: What-If
        run: |
          az deployment group what-if \
            --resource-group rg-ai-dev \
            --template-file infra/main.bicep \
            --parameters infra/parameters/dev.parameters.json
      
      - name: Deploy
        run: |
          az deployment group create \
            --resource-group rg-ai-dev \
            --template-file infra/main.bicep \
            --parameters infra/parameters/dev.parameters.json
      
      - name: Output Deployment Info
        id: outputs
        run: |
          OUTPUTS=$(az deployment group show \
            --resource-group rg-ai-dev \
            --name main \
            --query properties.outputs)
          echo "deployment_outputs=$OUTPUTS" >> $GITHUB_OUTPUT

  deploy-staging:
    needs: deploy-dev
    runs-on: ubuntu-latest
    environment: staging
    steps:
      # Similar to dev...

  deploy-prod:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: 
      name: production
      # Manual approval required
    steps:
      # Similar to dev with prod parameters...
```

### Agent Pipeline (Manifests)

```yaml
# .github/workflows/deploy-agents.yaml
name: Deploy Agents

on:
  push:
    branches: [main]
    paths:
      - 'agents/**'
      - 'knowledge/**'
  workflow_dispatch:

jobs:
  # See AGENT-CICD-APPROACH.md for full details
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy agents
        run: agent-deploy apply -f agents/ -e environments/prod.yaml
```

### Coordination Between Pipelines

```
┌──────────────────────────────────────────────────────────────────┐
│  Infrastructure Pipeline                                         │
│                                                                  │
│  1. Deploy AI Services + Model Deployments                       │
│  2. Output: MODEL_DEPLOYMENT_NAMES, FOUNDRY_ENDPOINT             │
│  3. Store outputs in GitHub Environment Variables                │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ Environment variables available
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  Agent Pipeline                                                  │
│                                                                  │
│  1. Read agent manifests                                         │
│  2. Resolve ${MODEL_DEPLOYMENT_NAME} from environment            │
│  3. Deploy agents referencing those model deployments            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 9. Common Operations

### Adding a New Model

1. **Update Bicep/Terraform** - Add new deployment to `modelsConfig`
2. **PR Review** - Ensure quota is available
3. **Deploy Infrastructure** - Run infrastructure pipeline
4. **Update Agent Manifests** - Reference new model by name
5. **Deploy Agents** - Agents now use new model

### Upgrading Model Version

1. **Update Bicep parameters** - Change `version` field
2. **What-If** - Preview changes
3. **Deploy** - Existing deployment is updated in-place
4. **No agent changes needed** - Agents reference by deployment name

### Increasing Capacity (TPM)

1. **Check quota** - Ensure subscription has available TPM
2. **Update Bicep parameters** - Change `capacity` field
3. **Deploy** - Capacity updated
4. **No agent changes needed**

### Deprecating a Model

1. **Update agent manifests first** - Point to new model
2. **Deploy agents** - Agents now use new model
3. **Update Bicep** - Remove old deployment
4. **Deploy infrastructure** - Old deployment deleted

---

## 10. Summary

### Decision Matrix

| Resource Type | Deployment Method | Reason |
|---------------|-------------------|--------|
| **Model Deployments** | Bicep/Terraform | Real ARM resources, native support, infrequent changes |
| **AI Services Account** | Bicep/Terraform | Infrastructure, shared resource |
| **Connections** | Bicep/Terraform | ARM resources, shared across agents |
| **APIM Instance** | Bicep/Terraform | Infrastructure, long deployment time |
| **Agents** | Manifest + CLI | Not ARM resources, frequent changes |
| **Vector Stores** | Manifest + CLI | Dynamic, tied to agent lifecycle |
| **Knowledge Base Files** | Manifest + CLI | Changes with agent updates |

### Best Practices

1. **Use Bicep/Terraform for model deployments** - Native ARM support, state management, drift detection

2. **Separate infrastructure and application pipelines** - Different change frequencies and approval processes

3. **Use environment-specific parameters** - Same templates, different capacity/configuration per environment

4. **Output deployment names** - Pass from infrastructure to application layer via environment variables

5. **Plan before apply** - Always preview changes (what-if / plan)

6. **Version control everything** - Both Bicep templates and agent manifests in Git

7. **Use Python SDK for ad-hoc operations** - Quick capacity changes, listing, emergency updates

---

## Related Documents

- [AGENT-CICD-APPROACH.md](./AGENT-CICD-APPROACH.md) - Manifest-based approach for agent deployments
- [labs/ai-agent-service/](./labs/ai-agent-service/) - Hands-on labs for AI agents
- [modules/cognitive-services/](./modules/cognitive-services/) - Reusable Bicep modules

---

*Document created: February 2026*
*Last updated: February 2026*
