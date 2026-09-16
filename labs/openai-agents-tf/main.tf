resource "random_string" "suffix" {
  length  = 10
  special = false
  upper   = false
}
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}
#### Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${local.resource_suffix}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
#### Application Insights
resource "azurerm_application_insights" "appinsights" {
  name                = "appinsights-${local.resource_suffix}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
}
#### API Management
resource "azapi_resource" "apim" {
  type                      = "Microsoft.ApiManagement/service@2024-06-01-preview"
  name                      = "${var.apim_resource_name}-${local.resource_suffix}"
  parent_id                 = azurerm_resource_group.rg.id
  location                  = local.location
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
#### Create APIM Logger
resource "azurerm_api_management_logger" "apim_logger" {
  name                = local.apim_logger_name
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  application_insights {
    instrumentation_key = azurerm_application_insights.appinsights.instrumentation_key
  }
}
#### Cognitive Services (OpenAI)
resource "azurerm_cognitive_account" "openai" {
  for_each = { for idx, val in var.openai_config : idx => val }

  location                           = each.value.location
  resource_group_name                = azurerm_resource_group.rg.name
  sku_name                           = var.openai_sku
  outbound_network_access_restricted = false
  public_network_access_enabled      = true
  kind                               = "OpenAI"
  custom_subdomain_name              = "${lower(each.value.name)}-${local.resource_suffix}"
  name                               = "${each.value.name}-${local.resource_suffix}"
}
resource "azurerm_cognitive_deployment" "deployment" {
  for_each = { for idx, val in var.openai_config : idx => val }

  name                 = var.openai_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai[each.key].id

  sku {
    name     = "GlobalStandard" // "GlobalStandard" // "Standard" // DataZoneStandard, GlobalBatch, GlobalStandard and ProvisionedManaged
    capacity = var.openai_model_capacity
  }

  model {
    format  = "OpenAI"
    name    = var.openai_model_name
    version = var.openai_model_version
  }
}
resource "azurerm_monitor_diagnostic_setting" "openai" {
  for_each = { for idx, val in var.openai_config : idx => val }

  name                       = "${lower(each.value.name)}-openai-diag"
  target_resource_id         = azurerm_cognitive_account.openai[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }

}
# Grant APIM identity access to OpenAI
resource "azurerm_role_assignment" "openai_user" {
  for_each             = { for idx, val in var.openai_config : idx => val }
  scope                = azurerm_cognitive_account.openai[each.key].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azapi_resource.apim.identity.0.principal_id
}
#### Logic App Workflow for Order Processing
resource "azapi_resource" "place_order_workflow" {
  type      = "Microsoft.Logic/workflows@2016-06-01"
  name      = "place_order_workflow"
  location  = "West US"
  parent_id = azurerm_resource_group.rg.id # Replace with your actual resource group or parent resource ID
  body = {
    properties = {
      state = "Enabled"
      definition = {
        "$schema"      = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
        contentVersion = "1.0.0.0"
        parameters = {
          "$connections" = {
            defaultValue = {}
            type         = "Object"
          }
        }
        triggers = {
          PlaceOrder = {
            type = "Request"
            kind = "Http"
            inputs = {
              schema = {
                type = "object"
                properties = {
                  sku = {
                    type = "string"
                  }
                  quantity = {
                    type = "integer"
                  }
                }
              }
            }
            description = "Place an Order to the specified sku and quantity."
          }
        }
        actions = {
          Condition = {
            actions = {
              UpdateStatusOk = {
                type = "Response"
                kind = "Http"
                inputs = {
                  statusCode = 200
                  body = {
                    status = "@concat('Order placed with id ', rand(1000,9000), ' for SKU ', triggerBody()?['sku'], ' with ', triggerBody()?['quantity'], ' items.')"
                  }
                }
                description = "Return the status for the order."
              }
            }
            runAfter = {}
            else = {
              actions = {
                UpdateStatusError = {
                  type = "Response"
                  kind = "Http"
                  inputs = {
                    statusCode = 200
                    body = {
                      status = "The order was not placed because the quantity exceeds the maximum limit of five items."
                    }
                  }
                  description = "Return the status for the order."
                }
              }
            }
            expression = {
              and = [
                {
                  lessOrEquals = [
                    "@triggerBody()?['quantity']",
                    5
                  ]
                }
              ]
            }
            type = "If"
          }
        }
        outputs = {}
      }
    }
  }
}
#### APIM APIs
resource "azurerm_api_management_api" "weather_api" {
  name                = "weather-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  revision            = "1"
  display_name        = "City Weather API"
  path                = var.weather_api_path
  protocols           = ["https"]
  import {
    content_format = "openapi+json"
    content_value  = file("${path.module}/city-weather-openapi.json")
  }
  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}
resource "azurerm_api_management_api" "place_order_api" {
  name                = "place-order-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  revision            = "1"
  display_name        = "Place Order API"
  path                = var.place_order_api_path
  protocols           = ["https"]
  import {
    content_format = "openapi+json"
    content_value  = file("place-order-openapi.json")
  }
  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}
resource "azurerm_api_management_api" "product_catalog_api" {
  name                = "product-catalog-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  revision            = "1"
  display_name        = "Product Catalog API"
  path                = var.product_catalog_api_path
  protocols           = ["https"]
  import {
    content_format = "openapi+json"
    content_value  = file("product-catalog-openapi.json")
  }
  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}
resource "azurerm_api_management_api" "apim-api-openai" {
  name                  = "apim-ai-gateway"
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
#### APIM Backend Pool
resource "azurerm_api_management_backend" "apim-backend-openai" {
  for_each = var.openai_config

  name                = each.value.name
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  protocol            = "http"
  url                 = "${azurerm_cognitive_account.openai[each.key].endpoint}openai"
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
            id = azurerm_api_management_backend.apim-backend-openai[k].id
          }
        ]
      }
    }
  }
}
resource "azapi_resource_action" "place_order_callback" {
  type        = "Microsoft.Logic/workflows/triggers/listCallbackUrl@2016-06-01"
  resource_id = "${azapi_resource.place_order_workflow.id}/triggers/PlaceOrder/listCallbackUrl"

  response_export_values = ["value"]
}
resource "azurerm_api_management_backend" "backend_place_order_api" {
  name                = "orderworkflow-backend"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  url                 = local.base_path
  protocol            = "http"

  credentials {
    query = {
      sig         = local.sig
      api-version = local.api-version
      sp          = local.sp
      sv          = local.sv
    }
  }

  depends_on = [azapi_resource_action.place_order_callback]
}
#### APIM API Policies
resource "azurerm_api_management_api_policy" "apim-openai-policy-openai" {
  api_name            = azurerm_api_management_api.apim-api-openai.name
  api_management_name = azurerm_api_management_api.apim-api-openai.api_management_name
  resource_group_name = azurerm_api_management_api.apim-api-openai.resource_group_name

  xml_content = replace(file("policy.xml"), "{backend-id}", azapi_resource.apim-backend-pool-openai.name)
}
resource "azurerm_api_management_api_policy" "weather_api_policy" {
  api_name            = azurerm_api_management_api.weather_api.name
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  xml_content         = file("city-weather-mock-policy.xml")
}
resource "azurerm_api_management_api_policy" "place_order_api_policy" {
  api_name            = azurerm_api_management_api.place_order_api.name
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  xml_content         = file("place-order-policy.xml")
  depends_on          = [azurerm_api_management_backend.backend_place_order_api]
}
resource "azurerm_api_management_api_policy" "product_catalog_api_policy" {
  api_name            = azurerm_api_management_api.product_catalog_api.name
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azapi_resource.apim.name
  xml_content         = file("product-catalog-mock-policy.xml")
}
#### APIM API Diagnostics
resource "azurerm_api_management_api_diagnostic" "weather_api_diagnostics" {

  identifier                = "applicationinsights"
  api_name                  = azurerm_api_management_api.weather_api.name
  resource_group_name       = azurerm_resource_group.rg.name
  api_management_name       = azapi_resource.apim.name
  api_management_logger_id  = azurerm_api_management_logger.apim_logger.id
  log_client_ip             = true
  sampling_percentage       = 100
  always_log_errors         = true
  verbosity                 = "verbose"
  http_correlation_protocol = "W3C"
  frontend_request {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  backend_request {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  frontend_response {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  backend_response {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }
}
resource "azurerm_api_management_api_diagnostic" "place_order_api_diagnostics" {
  identifier                = "applicationinsights"
  api_name                  = azurerm_api_management_api.place_order_api.name
  resource_group_name       = azurerm_resource_group.rg.name
  api_management_name       = azapi_resource.apim.name
  api_management_logger_id  = azurerm_api_management_logger.apim_logger.id
  log_client_ip             = true
  sampling_percentage       = 100
  always_log_errors         = true
  verbosity                 = "verbose"
  http_correlation_protocol = "W3C"
  frontend_request {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  backend_request {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  frontend_response {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  backend_response {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }
}
resource "azurerm_api_management_api_diagnostic" "product_catalog_api_diagnostics" {
  identifier                = "applicationinsights"
  api_name                  = azurerm_api_management_api.product_catalog_api.name
  resource_group_name       = azurerm_resource_group.rg.name
  api_management_name       = azapi_resource.apim.name
  api_management_logger_id  = azurerm_api_management_logger.apim_logger.id
  log_client_ip             = true
  sampling_percentage       = 100
  always_log_errors         = true
  verbosity                 = "verbose"
  http_correlation_protocol = "W3C"
  frontend_request {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  backend_request {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  frontend_response {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  backend_response {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }


}
resource "azurerm_api_management_api_diagnostic" "openai_api_diagnostics" {
  identifier                = "applicationinsights"
  api_name                  = azurerm_api_management_api.apim-api-openai.name
  resource_group_name       = azurerm_resource_group.rg.name
  api_management_name       = azapi_resource.apim.name
  api_management_logger_id  = azurerm_api_management_logger.apim_logger.id
  log_client_ip             = true
  sampling_percentage       = 100
  always_log_errors         = true
  verbosity                 = "verbose"
  http_correlation_protocol = "W3C"
  frontend_request {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  backend_request {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  frontend_response {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }

  backend_response {
    headers_to_log = local.log_settings.headers
    body_bytes     = local.log_settings.body.bytes
  }


}
#### APIM API Subscriptions
resource "azurerm_api_management_subscription" "openai-subscription" {
  display_name        = "openai-subscription"
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  allow_tracing       = true
  state               = "active"
}
resource "azurerm_api_management_subscription" "tools-apis-subscription" {
  display_name        = "Tools APIs Subscription"
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  allow_tracing       = true
  state               = "active"
}