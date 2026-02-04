# AI Gateway Terraform Patterns

Patterns from this repository for AI Gateway scenarios with Azure API Management.

## Table of Contents

- [Complete AI Gateway Example](#complete-ai-gateway-example)
- [Azure AI Services Integration](#azure-ai-services-integration)
- [Load Balancing Pattern](#load-balancing-pattern)
- [Variables Pattern](#variables-pattern)
- [Providers Configuration](#providers-configuration)

---

## Complete AI Gateway Example

Full example from `labs/backend-pool-load-balancing-tf`:

```hcl
# Random suffix for unique names
resource "random_string" "random" {
  length  = 8
  lower   = true
  upper   = false
  special = false
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

# Azure AI Services (using azapi for latest features)
resource "azapi_resource" "ai-services" {
  for_each = var.aiservices_config

  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  parent_id = azurerm_resource_group.rg.id
  name      = "${each.value.name}-${random_string.random.result}"
  location  = each.value.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = "${lower(each.value.name)}-${random_string.random.result}"
      disableLocalAuth       = false
      publicNetworkAccess    = "Enabled"
    }
  }
}

# AI Project
resource "azapi_resource" "ai-project" {
  for_each = var.aiservices_config

  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  parent_id = azapi_resource.ai-services[each.key].id
  name      = "ai-project-${each.key}"
  location  = each.value.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {}
  }
}

# Model Deployment
resource "azurerm_cognitive_deployment" "gpt-4o" {
  for_each = var.aiservices_config

  name                 = var.model_deployment_name
  cognitive_account_id = azapi_resource.ai-services[each.key].id

  sku {
    name     = "GlobalStandard"
    capacity = var.model_capacity
  }

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }
}

# Role Assignment for current user
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "ai_project_manager" {
  for_each = var.aiservices_config

  scope                = azapi_resource.ai-services[each.key].id
  role_definition_name = "Azure AI Project Manager"
  principal_id         = data.azurerm_client_config.current.object_id
}

# APIM Instance
resource "azurerm_api_management" "apim" {
  name                          = "${var.apim_resource_name}-${random_string.random.result}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  publisher_name                = "My Company"
  publisher_email               = "noreply@microsoft.com"
  sku_name                      = "BasicV2_1"
  virtual_network_type          = "None"
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

# Role Assignment for APIM to access Cognitive Services
resource "azurerm_role_assignment" "cognitive_services_user" {
  for_each = var.aiservices_config

  scope                = azapi_resource.ai-services[each.key].id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}

# OpenAI API
resource "azurerm_api_management_api" "openai" {
  name                  = "apim-api-openai"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  description           = "Azure OpenAI APIs for completions and search"
  display_name          = "OpenAI"
  path                  = "openai"
  protocols             = ["https"]
  service_url           = null
  subscription_required = false
  api_type              = "http"

  import {
    content_format = "openapi-link"
    content_value  = var.model_api_spec_url
  }

  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}

# Backends with Circuit Breaker
resource "azapi_resource" "backend" {
  for_each = var.aiservices_config

  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  parent_id = azurerm_api_management.apim.id
  name      = "backend-${each.key}"

  body = {
    properties = {
      url         = "${azapi_resource.ai-services[each.key].output.properties.endpoint}openai"
      protocol    = "http"
      description = "Inference backend"

      circuitBreaker = {
        rules = [
          {
            failureCondition = {
              count            = 1
              errorReasons     = ["Server errors"]
              interval         = "PT5M"
              statusCodeRanges = [{ min = 429, max = 429 }]
            }
            name             = "InferenceBreakerRule"
            tripDuration     = "PT1M"
            acceptRetryAfter = true
          }
        ]
      }
    }
  }
}

# Backend Pool
resource "azapi_resource" "backend_pool" {
  type                      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  name                      = "apim-backend-pool"
  parent_id                 = azurerm_api_management.apim.id
  schema_validation_enabled = false

  body = {
    properties = {
      description = "Load balancer for multiple inference endpoints"
      type        = "Pool"

      pool = {
        services = [
          for k, v in var.aiservices_config :
          {
            id       = azapi_resource.backend[k].id
            priority = v.priority
            weight   = v.weight
          }
        ]
      }
    }
  }
}

# API Policy
resource "azurerm_api_management_api_policy" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = replace(file("policy.xml"), "{backend-id}", azapi_resource.backend_pool.name)
}

# Subscription
resource "azurerm_api_management_subscription" "openai" {
  display_name        = "apim-api-subscription-openai"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_id              = replace(azurerm_api_management_api.openai.id, "/;rev=.*/", "")
  allow_tracing       = true
  state               = "active"
}
```

---

## Azure AI Services Integration

### Cognitive Services Account (azapi)

```hcl
resource "azapi_resource" "ai_services" {
  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  parent_id = azurerm_resource_group.rg.id
  name      = "ai-services-${random_string.suffix.result}"
  location  = var.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = "ai-${random_string.suffix.result}"
      disableLocalAuth       = false
      publicNetworkAccess    = "Enabled"
    }
  }
}
```

### Model Deployment

```hcl
resource "azurerm_cognitive_deployment" "model" {
  name                 = "gpt-4o-mini"
  cognitive_account_id = azapi_resource.ai_services.id

  sku {
    name     = "GlobalStandard"  # GlobalStandard, Standard, DataZoneStandard, GlobalBatch, ProvisionedManaged
    capacity = 1
  }

  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }
}
```

### RBAC for APIM to AI Services

```hcl
resource "azurerm_role_assignment" "apim_cognitive" {
  scope                = azapi_resource.ai_services.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}
```

---

## Load Balancing Pattern

### Multiple Backends with Priority and Weight

```hcl
variable "backends_config" {
  default = {
    primary = {
      name     = "primary"
      location = "uksouth"
      priority = 1
      weight   = 100
    }
    secondary = {
      name     = "secondary"
      location = "swedencentral"
      priority = 2
      weight   = 50
    }
    tertiary = {
      name     = "tertiary"
      location = "francecentral"
      priority = 2
      weight   = 50
    }
  }
}

# Create backends dynamically
resource "azapi_resource" "backends" {
  for_each = var.backends_config

  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  parent_id = azurerm_api_management.apim.id
  name      = "backend-${each.key}"

  body = {
    properties = {
      url         = "https://${each.value.name}.openai.azure.com/openai"
      protocol    = "http"
      description = "Backend in ${each.value.location}"

      circuitBreaker = {
        rules = [
          {
            failureCondition = {
              count            = 1
              errorReasons     = ["Server errors"]
              interval         = "PT5M"
              statusCodeRanges = [{ min = 429, max = 429 }]
            }
            name             = "BreakerRule"
            tripDuration     = "PT1M"
            acceptRetryAfter = true
          }
        ]
      }
    }
  }
}

# Backend pool with load balancing
resource "azapi_resource" "backend_pool" {
  type                      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  name                      = "backend-pool"
  parent_id                 = azurerm_api_management.apim.id
  schema_validation_enabled = false

  body = {
    properties = {
      description = "Load balanced backend pool"
      type        = "Pool"
      pool = {
        services = [
          for k, v in var.backends_config : {
            id       = azapi_resource.backends[k].id
            priority = v.priority
            weight   = v.weight
          }
        ]
      }
    }
  }
}
```

---

## Variables Pattern

### Recommended Variables Structure

```hcl
# variables.tf

variable "resource_group_name" {
  type        = string
  default     = "rg-ai-gateway"
  description = "Resource group name"
}

variable "resource_group_location" {
  type        = string
  default     = "westeurope"
  description = "Azure region for resources"
}

variable "aiservices_config" {
  description = "Configuration for AI Services instances"
  default = {
    primary = {
      name     = "foundry1"
      location = "uksouth"
      priority = 1
      weight   = 100
    }
    secondary = {
      name     = "foundry2"
      location = "swedencentral"
      priority = 2
      weight   = 50
    }
  }
}

variable "model_deployment_name" {
  type        = string
  default     = "gpt-4o-mini"
  description = "Model deployment name"
}

variable "model_name" {
  type        = string
  default     = "gpt-4o-mini"
  description = "Model name"
}

variable "model_version" {
  type        = string
  default     = "2024-07-18"
  description = "Model version"
}

variable "model_capacity" {
  type        = number
  default     = 1
  description = "Model deployment capacity"
}

variable "model_api_spec_url" {
  type        = string
  default     = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-10-21/inference.json"
  description = "OpenAPI spec URL for the model API"
}

variable "apim_resource_name" {
  type        = string
  default     = "apim"
  description = "APIM resource name prefix"
}

variable "apim_sku" {
  type        = string
  default     = "BasicV2"
  description = "APIM SKU tier"

  validation {
    condition     = contains(["Basic", "BasicV2", "Consumption", "Developer", "Premium", "PremiumV2", "Standard", "StandardV2"], var.apim_sku)
    error_message = "Invalid SKU. Must be one of: Basic, BasicV2, Consumption, Developer, Premium, PremiumV2, Standard, StandardV2."
  }
}
```

---

## Providers Configuration

### Required Providers

```hcl
# providers.tf

terraform {
  required_version = ">=1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

### Outputs

```hcl
# outputs.tf

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Resource group name"
}

output "apim_name" {
  value       = azurerm_api_management.apim.name
  description = "API Management service name"
}

output "apim_gateway_url" {
  value       = azurerm_api_management.apim.gateway_url
  description = "APIM gateway URL"
}

output "subscription_key" {
  value       = azurerm_api_management_subscription.openai.primary_key
  sensitive   = true
  description = "Subscription key for API access"
}
```

---

## Policy File Pattern

Store policies in separate XML files and reference with `file()`:

```hcl
# policy.xml
resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  # Simple file reference
  xml_content = file("policy.xml")
}

# With variable substitution
resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  # Replace placeholder with actual value
  xml_content = replace(file("policy.xml"), "{backend-id}", azapi_resource.backend_pool.name)
}

# With templatefile for multiple substitutions
resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = templatefile("policy.xml.tpl", {
    backend_id = azapi_resource.backend_pool.name
    rate_limit = var.rate_limit
  })
}
```
