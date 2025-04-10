resource "random_string" "random" {
  length  = 8
  lower   = true
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_ai_services" "ai-services" {
  for_each = var.openai_config

  name                               = "${each.value.name}-${random_string.random.result}"
  location                           = each.value.location
  resource_group_name                = azurerm_resource_group.rg.name
  sku_name                           = var.openai_sku
  local_authentication_enabled       = true
  public_network_access              = "Enabled"
  outbound_network_access_restricted = false
  custom_subdomain_name              = "${lower(each.value.name)}-${random_string.random.result}"
}

resource "azurerm_cognitive_deployment" "gpt-4o" {
  for_each = var.openai_config

  name                 = var.openai_deployment_name
  cognitive_account_id = azurerm_ai_services.ai-services[each.key].id

  sku {
    name     = "GlobalStandard" # "GlobalStandard" # "Standard" # DataZoneStandard, GlobalBatch, GlobalStandard and ProvisionedManaged
    capacity = var.openai_model_capacity
  }

  model {
    format  = "OpenAI"
    name    = var.openai_model_name    # "gpt-4o"
    version = var.openai_model_version # "2024-08-06"
  }
}

# Terraform azurerm provider doesn't support yet creating API Management instances with v2 SKU.
resource "azapi_resource" "apim" {
  type                      = "Microsoft.ApiManagement/service@2024-06-01-preview"
  name                      = "${var.apim_resource_name}-${random_string.random.result}"
  parent_id                 = azurerm_resource_group.rg.id
  location                  = var.apim_resource_location # SKU BasicV2 is not yet supported in the region Sweden Central
  schema_validation_enabled = true

  identity {
    type = "SystemAssigned"
  }

  body = {
    sku = {
      name     = var.apim_sku
      capacity = 1
    }
    properties = {
      publisherEmail      = "noreply@microsoft.com"
      publisherName       = "Microsoft"
      virtualNetworkType  = "None"
      publicNetworkAccess = "Enabled"
    }
  }

  response_export_values = ["*"]
}

resource "azurerm_role_assignment" "Cognitive-Services-OpenAI-User" {
  for_each = var.openai_config

  scope                = azurerm_ai_services.ai-services[each.key].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azapi_resource.apim.identity.0.principal_id
}

resource "azurerm_api_management_api" "apim-api-openai" {
  name                  = "apim-api-openai"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azapi_resource.apim.name
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
    content_value  = var.openai_api_spec_url
  }

  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}

resource "azurerm_api_management_backend" "apim-backend-openai" {
  for_each = var.openai_config

  name                = each.value.name
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  protocol            = "http"
  url                 = "${azurerm_ai_services.ai-services[each.key].endpoint}openai"
}

resource "azapi_update_resource" "apim-backend-circuit-breaker" {
  for_each = var.openai_config

  type        = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  resource_id = azurerm_api_management_backend.apim-backend-openai[each.key].id

  body = {
    properties = {
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
            name             = "openAIBreakerRule"
            tripDuration     = "PT1M"
            acceptRetryAfter = true // respects the Retry-After header
          }
        ]
      }
    }
  }
}

resource "azapi_resource" "apim-backend-pool-openai" {
  type                      = "Microsoft.ApiManagement/service/backends@2023-09-01-preview"
  name                      = "apim-backend-pool"
  parent_id                 = azapi_resource.apim.id
  schema_validation_enabled = false

  body = {
    properties = {
      type = "Pool"
      pool = {
        services = [
          for k, v in var.openai_config :
          {
            id       = azurerm_api_management_backend.apim-backend-openai[k].id
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
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_id              = replace(azurerm_api_management_api.apim-api-openai.id, "/;rev=.*/", "")
  allow_tracing       = true
  state               = "active"
}