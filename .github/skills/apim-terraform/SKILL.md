---
name: apim-terraform
description: Guide for creating Terraform files for Azure API Management (APIM) and related Azure services. Use when users want to create, modify, or understand Terraform configurations for APIM instances, APIs, backends, subscriptions, policies, products, loggers, diagnostics, and supporting infrastructure using the azurerm provider. This skill provides HCL syntax, resource definitions, and patterns from the Terraform Registry and this repository.
---

# APIM Terraform Skill

Guide for creating Terraform files for Azure API Management and related Azure services.

## Quick Start

### Minimum Viable APIM Deployment

```hcl
terraform {
  required_version = ">=1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "example-resources"
  location = "westeurope"
}

resource "azurerm_api_management" "apim" {
  name                = "example-apim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "My Company"
  publisher_email     = "company@example.com"
  sku_name            = "Developer_1"
}
```

## Resource Types

### Core APIM Resources

| Resource | Description |
|----------|-------------|
| `azurerm_api_management` | APIM service instance |
| `azurerm_api_management_api` | API definition |
| `azurerm_api_management_api_operation` | API operation |
| `azurerm_api_management_backend` | Backend service |
| `azurerm_api_management_subscription` | Subscription for API access |
| `azurerm_api_management_product` | Product grouping APIs |
| `azurerm_api_management_product_api` | Link product to API |

### Policy Resources

| Resource | Description |
|----------|-------------|
| `azurerm_api_management_policy` | Global policy |
| `azurerm_api_management_api_policy` | API-level policy |
| `azurerm_api_management_api_operation_policy` | Operation-level policy |
| `azurerm_api_management_product_policy` | Product-level policy |
| `azurerm_api_management_policy_fragment` | Reusable policy fragment |

### Monitoring Resources

| Resource | Description |
|----------|-------------|
| `azurerm_api_management_logger` | Logger (App Insights/Event Hub) |
| `azurerm_api_management_diagnostic` | Service-level diagnostics |
| `azurerm_api_management_api_diagnostic` | API-level diagnostics |

### Configuration Resources

| Resource | Description |
|----------|-------------|
| `azurerm_api_management_named_value` | Named value (property) |
| `azurerm_api_management_certificate` | Certificate |
| `azurerm_api_management_authorization_server` | OAuth server |
| `azurerm_api_management_openid_connect_provider` | OpenID provider |

For complete resource reference, see [references/apim-resources.md](references/apim-resources.md).

## Essential Patterns

### APIM Service with Managed Identity

```hcl
resource "azurerm_api_management" "apim" {
  name                          = "example-apim"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  publisher_name                = "My Company"
  publisher_email               = "noreply@example.com"
  sku_name                      = "BasicV2_1"
  virtual_network_type          = "None"
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }
}
```

### API with OpenAPI Import

```hcl
resource "azurerm_api_management_api" "api" {
  name                  = "example-api"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "Example API"
  path                  = "api"
  protocols             = ["https"]
  subscription_required = false
  api_type              = "http"

  import {
    content_format = "openapi-link"
    content_value  = "https://example.com/openapi.json"
  }

  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}
```

### Backend with Circuit Breaker (azapi)

For advanced backend features like circuit breakers, use the azapi provider:

```hcl
resource "azapi_resource" "backend" {
  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  parent_id = azurerm_api_management.apim.id
  name      = "example-backend"

  body = {
    properties = {
      url         = "https://backend.example.com/api"
      protocol    = "http"
      description = "Backend service"

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
```

### Backend Pool for Load Balancing (azapi)

```hcl
resource "azapi_resource" "backend_pool" {
  type                      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  name                      = "backend-pool"
  parent_id                 = azurerm_api_management.apim.id
  schema_validation_enabled = false

  body = {
    properties = {
      description = "Load balancer for multiple backends"
      type        = "Pool"

      pool = {
        services = [
          { id = azapi_resource.backend1.id, priority = 1, weight = 100 },
          { id = azapi_resource.backend2.id, priority = 2, weight = 50 }
        ]
      }
    }
  }
}
```

### API Policy with XML

```hcl
resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="backend-pool" />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}
```

### Policy from File with Variable Substitution

```hcl
resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = replace(file("policy.xml"), "{backend-id}", azapi_resource.backend_pool.name)
}
```

### Subscription

```hcl
resource "azurerm_api_management_subscription" "subscription" {
  display_name        = "example-subscription"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_id              = replace(azurerm_api_management_api.api.id, "/;rev=.*/", "")
  allow_tracing       = true
  state               = "active"
}
```

### Product

```hcl
resource "azurerm_api_management_product" "product" {
  product_id            = "example-product"
  api_management_name   = azurerm_api_management.apim.name
  resource_group_name   = azurerm_resource_group.rg.name
  display_name          = "Example Product"
  subscription_required = true
  approval_required     = true
  published             = true
}

resource "azurerm_api_management_product_api" "product_api" {
  api_name            = azurerm_api_management_api.api.name
  product_id          = azurerm_api_management_product.product.product_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
}
```

### Logging with Application Insights

```hcl
resource "azurerm_application_insights" "appinsights" {
  name                = "example-appinsights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

resource "azurerm_api_management_logger" "logger" {
  name                = "appinsights-logger"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  resource_id         = azurerm_application_insights.appinsights.id

  application_insights {
    instrumentation_key = azurerm_application_insights.appinsights.instrumentation_key
  }
}

resource "azurerm_api_management_diagnostic" "diagnostic" {
  identifier               = "applicationinsights"
  resource_group_name      = azurerm_resource_group.rg.name
  api_management_name      = azurerm_api_management.apim.name
  api_management_logger_id = azurerm_api_management_logger.logger.id

  sampling_percentage       = 5.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "verbose"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes     = 32
    headers_to_log = ["content-type", "accept", "origin"]
  }

  frontend_response {
    body_bytes     = 32
    headers_to_log = ["content-type", "content-length", "origin"]
  }

  backend_request {
    body_bytes     = 32
    headers_to_log = ["content-type", "accept", "origin"]
  }

  backend_response {
    body_bytes     = 32
    headers_to_log = ["content-type", "content-length", "origin"]
  }
}
```

### Named Values

```hcl
resource "azurerm_api_management_named_value" "value" {
  name                = "example-property"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "ExampleProperty"
  value               = "Example Value"
  secret              = false
}
```

### Role Assignment for Cognitive Services

```hcl
resource "azurerm_role_assignment" "cognitive_services_user" {
  scope                = azurerm_cognitive_account.ai_services.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}
```

## SKU Reference

| SKU | Format | Notes |
|-----|--------|-------|
| Consumption | `Consumption_0` | Auto-scaling, capacity always 0 |
| Developer | `Developer_1` | Development/testing |
| Basic | `Basic_1` or `Basic_2` | Entry-level production |
| BasicV2 | `BasicV2_1` | New v2 tier |
| Standard | `Standard_1` to `Standard_4` | Production workloads |
| StandardV2 | `StandardV2_1` | New v2 tier |
| Premium | `Premium_1` to `Premium_12` | Enterprise features |
| PremiumV2 | `PremiumV2_1` | New v2 tier |

## Best Practices

1. **Use managed identity** for secure access to backend services
2. **Use azapi provider** for features not yet in azurerm (circuit breakers, backend pools)
3. **Store policies in separate files** and use `file()` function
4. **Use variables** for configurable values like locations, SKUs, and names
5. **Use `for_each`** for multiple similar resources (backends, deployments)
6. **Strip revision suffix** from API ID for subscriptions: `replace(api.id, "/;rev=.*/", "")`
7. **Add random suffix** to globally unique names using `random_string`

## Provider Requirements

```hcl
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

## References

- [references/apim-resources.md](references/apim-resources.md) - Complete APIM resource definitions
- [references/ai-gateway-patterns.md](references/ai-gateway-patterns.md) - AI Gateway patterns from this repository
