resource "random_string" "random" {
  length  = 8
  lower   = true
  upper   = false
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

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

resource "azurerm_cognitive_deployment" "gpt-4o" {
  for_each = var.aiservices_config

  name                 = var.model_deployment_name
  cognitive_account_id = azapi_resource.ai-services[each.key].id

  sku {
    name     = "GlobalStandard" # "GlobalStandard" # "Standard" # DataZoneStandard, GlobalBatch, GlobalStandard and ProvisionedManaged
    capacity = var.model_capacity
  }

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }
}

resource "azurerm_role_assignment" "Azure-AI-Project-Manager" {
  for_each = var.aiservices_config

  scope                = azapi_resource.ai-services[each.key].id
  role_definition_name = "Azure AI Project Manager"
  principal_id         = data.azurerm_client_config.current.object_id
}

data "azurerm_client_config" "current" {}

resource "azurerm_api_management" "apim" {
  name                          = "${var.apim_resource_name}-${random_string.random.result}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  publisher_name                = "My Company"
  publisher_email               = "noreply@microsoft.com"
  sku_name                      = "BasicV2_1" # Consumption, Developer, Basic, BasicV2, Standard, StandardV2, Premium and PremiumV2
  virtual_network_type          = "None"      # None, External, Internal
  public_network_access_enabled = true        # false applies only when using private endpoint as the exclusive access method

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "Cognitive-Services-User" {
  for_each = var.aiservices_config

  scope                = azapi_resource.ai-services[each.key].id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_api_management.apim.identity.0.principal_id
}

resource "azurerm_api_management_api" "apim-api-openai" {
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

resource "azapi_resource" "apim-backend" {
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
              count = 1
              errorReasons = [
                "Server errors"
              ]
              interval = "PT5M"
              statusCodeRanges = [
                {
                  min = 429
                  max = 429
                }
              ]
            }
            name             = "InferenceBreakerRule"
            tripDuration     = "PT1M"
            acceptRetryAfter = true // respects the Retry-After header
          }
        ]
      }
    }
  }
}

resource "azapi_resource" "apim-backend-pool-openai" {
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
            id       = azapi_resource.apim-backend[k].id
            priority = v.priority
            weight   = v.weight
          }
        ]
      }
    }
  }
}

resource "azurerm_api_management_api_policy" "apim-openai-policy-openai" {
  api_name            = azurerm_api_management_api.apim-api-openai.name
  api_management_name = azurerm_api_management_api.apim-api-openai.api_management_name
  resource_group_name = azurerm_api_management_api.apim-api-openai.resource_group_name

  xml_content = replace(file("policy.xml"), "{backend-id}", azapi_resource.apim-backend-pool-openai.name)
}

resource "azurerm_api_management_subscription" "apim-api-subscription-openai" {
  display_name        = "apim-api-subscription-openai"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_id              = replace(azurerm_api_management_api.apim-api-openai.id, "/;rev=.*/", "")
  allow_tracing       = true
  state               = "active"
}
