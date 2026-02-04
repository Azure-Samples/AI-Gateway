# APIM Terraform Resources Reference

Complete reference for Azure API Management Terraform resources in the azurerm provider.

## Table of Contents

- [Service Resources](#service-resources)
- [API Resources](#api-resources)
- [Backend Resources](#backend-resources)
- [Policy Resources](#policy-resources)
- [Product Resources](#product-resources)
- [Subscription Resources](#subscription-resources)
- [Logging and Diagnostics](#logging-and-diagnostics)
- [Security Resources](#security-resources)
- [Gateway Resources](#gateway-resources)
- [Workspace Resources](#workspace-resources)
- [Data Sources](#data-sources)

---

## Service Resources

### azurerm_api_management

Main APIM service instance.

**Required Arguments:**
- `name` - Unique name for the APIM service
- `location` - Azure region
- `resource_group_name` - Resource group name
- `publisher_name` - Publisher/company name
- `publisher_email` - Publisher email
- `sku_name` - SKU in format `{tier}_{capacity}` (e.g., `Developer_1`, `BasicV2_1`)

**Optional Arguments:**
- `identity` - Managed identity block (`type`: `SystemAssigned`, `UserAssigned`, or both)
- `virtual_network_type` - `None`, `External`, or `Internal`
- `virtual_network_configuration` - Subnet configuration
- `public_network_access_enabled` - Enable public access
- `zones` - Availability zones (Premium tier only)
- `hostname_configuration` - Custom domains
- `notification_sender_email` - Notification email
- `protocols` - Protocol settings (`http2_enabled`)
- `security` - TLS/SSL cipher settings
- `tags` - Resource tags

**Attributes:**
- `id` - Resource ID
- `gateway_url` - Gateway URL
- `management_api_url` - Management API URL
- `portal_url` - Publisher portal URL
- `developer_portal_url` - Developer portal URL
- `public_ip_addresses` - Public IPs
- `private_ip_addresses` - Private IPs
- `identity.principal_id` - Managed identity principal ID
- `identity.tenant_id` - Managed identity tenant ID

**Example:**
```hcl
resource "azurerm_api_management" "apim" {
  name                          = "my-apim"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  publisher_name                = "My Company"
  publisher_email               = "admin@example.com"
  sku_name                      = "BasicV2_1"
  virtual_network_type          = "None"
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "production"
  }
}
```

---

## API Resources

### azurerm_api_management_api

API definition within APIM.

**Required Arguments:**
- `name` - API name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `revision` - API revision number

**Optional Arguments:**
- `display_name` - Display name (required unless `source_api_id` set)
- `path` - URL path (required unless `source_api_id` set)
- `protocols` - List: `http`, `https`, `ws`, `wss`
- `api_type` - `http`, `graphql`, `soap`, `websocket`
- `service_url` - Backend service URL
- `subscription_required` - Require subscription key
- `import` - Import API definition (OpenAPI, Swagger, WSDL)
- `subscription_key_parameter_names` - Custom parameter names
- `oauth2_authorization` - OAuth2 configuration
- `openid_authentication` - OpenID Connect configuration
- `version` - API version
- `version_set_id` - Version set ID

**Import Block:**
```hcl
import {
  content_format = "openapi-link"  # or openapi, swagger-json, swagger-link-json, wsdl, wsdl-link
  content_value  = "https://example.com/openapi.json"
}
```

**Example:**
```hcl
resource "azurerm_api_management_api" "api" {
  name                  = "example-api"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "Example API"
  path                  = "example"
  protocols             = ["https"]
  subscription_required = true
  api_type              = "http"

  import {
    content_format = "openapi-link"
    content_value  = var.api_spec_url
  }

  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}
```

### azurerm_api_management_api_operation

Individual operation within an API.

**Required Arguments:**
- `operation_id` - Operation identifier
- `api_name` - API name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `display_name` - Display name
- `method` - HTTP method (GET, POST, PUT, DELETE, etc.)
- `url_template` - URL template (e.g., `/users/{id}`)

**Optional Arguments:**
- `description` - Operation description
- `request` - Request definition
- `response` - Response definitions
- `template_parameter` - URL template parameters

### azurerm_api_management_api_version_set

Version set for API versioning.

**Required Arguments:**
- `name` - Version set name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `display_name` - Display name
- `versioning_scheme` - `Segment`, `Query`, or `Header`

**Optional Arguments:**
- `version_header_name` - Header name (when scheme is `Header`)
- `version_query_name` - Query parameter name (when scheme is `Query`)

---

## Backend Resources

### azurerm_api_management_backend

Backend service definition.

**Required Arguments:**
- `name` - Backend name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `protocol` - `http` or `soap`
- `url` - Backend URL (format: `https://backend.com/api`, no trailing slash)

**Optional Arguments:**
- `description` - Backend description
- `resource_id` - ARM Resource ID for Logic Apps, Function Apps, or Service Fabric
- `title` - Backend title
- `credentials` - Credentials block (authorization, certificates, headers, query params)
- `proxy` - Proxy configuration
- `tls` - TLS validation settings
- `circuit_breaker_rule` - Circuit breaker configuration (see azapi for better support)

**Note:** For advanced features like backend pools and circuit breakers, use the azapi provider.

**Example:**
```hcl
resource "azurerm_api_management_backend" "backend" {
  name                = "example-backend"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = "https://backend.example.com/api"
  description         = "Example backend service"

  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}
```

### Backend with azapi (Advanced Features)

```hcl
resource "azapi_resource" "backend" {
  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  parent_id = azurerm_api_management.apim.id
  name      = "advanced-backend"

  body = {
    properties = {
      url         = "https://backend.example.com/api"
      protocol    = "http"
      description = "Backend with circuit breaker"

      circuitBreaker = {
        rules = [
          {
            failureCondition = {
              count            = 3
              errorReasons     = ["Server errors"]
              interval         = "PT5M"
              statusCodeRanges = [{ min = 500, max = 599 }]
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

### Backend Pool with azapi

```hcl
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
          { id = azapi_resource.backend1.id, priority = 1, weight = 100 },
          { id = azapi_resource.backend2.id, priority = 2, weight = 50 }
        ]
      }
    }
  }
}
```

---

## Policy Resources

### azurerm_api_management_policy

Global APIM policy.

**Required Arguments:**
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name

**Optional Arguments (one required):**
- `xml_content` - Inline XML policy
- `xml_link` - URL to policy XML file

### azurerm_api_management_api_policy

API-level policy.

**Required Arguments:**
- `api_name` - API name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name

**Optional Arguments (one required):**
- `xml_content` - Inline XML policy
- `xml_link` - URL to policy XML file

**Example:**
```hcl
resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit calls="100" renewal-period="60" />
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

### azurerm_api_management_api_operation_policy

Operation-level policy.

**Required Arguments:**
- `operation_id` - Operation ID
- `api_name` - API name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `xml_content` or `xml_link`

### azurerm_api_management_product_policy

Product-level policy.

**Required Arguments:**
- `product_id` - Product ID
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `xml_content` or `xml_link`

### azurerm_api_management_policy_fragment

Reusable policy fragment.

**Required Arguments:**
- `name` - Fragment name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `value` - XML fragment content
- `format` - `xml` or `rawxml`

---

## Product Resources

### azurerm_api_management_product

Product definition.

**Required Arguments:**
- `product_id` - Product identifier
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `display_name` - Display name
- `published` - Is product published

**Optional Arguments:**
- `description` - Product description
- `subscription_required` - Require subscription (default: true)
- `approval_required` - Require approval (only when `subscription_required` is true)
- `subscriptions_limit` - Max subscriptions per user
- `terms` - Terms of service

### azurerm_api_management_product_api

Link API to product.

**Required Arguments:**
- `api_name` - API name
- `product_id` - Product ID
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name

### azurerm_api_management_product_group

Link group to product.

**Required Arguments:**
- `product_id` - Product ID
- `group_name` - Group name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name

---

## Subscription Resources

### azurerm_api_management_subscription

Subscription for API access.

**Required Arguments:**
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `display_name` - Display name

**Optional Arguments:**
- `product_id` - Product ID (mutually exclusive with `api_id`)
- `api_id` - API ID (mutually exclusive with `product_id`)
- `user_id` - User ID
- `state` - `active`, `cancelled`, `expired`, `rejected`, `submitted`, `suspended`
- `primary_key` - Primary subscription key
- `secondary_key` - Secondary subscription key
- `allow_tracing` - Enable tracing

**Note:** Strip revision from API ID: `replace(api.id, "/;rev=.*/", "")`

**Example:**
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

---

## Logging and Diagnostics

### azurerm_api_management_logger

Logger for Application Insights or Event Hub.

**Required Arguments:**
- `name` - Logger name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name

**Optional Arguments:**
- `application_insights` - App Insights configuration
- `eventhub` - Event Hub configuration
- `resource_id` - Target resource ID
- `description` - Logger description
- `buffered` - Buffer records before publishing (default: true)

**Application Insights Block:**
```hcl
application_insights {
  instrumentation_key = azurerm_application_insights.ai.instrumentation_key
  # or
  connection_string   = azurerm_application_insights.ai.connection_string
}
```

### azurerm_api_management_diagnostic

Service-level diagnostics.

**Required Arguments:**
- `identifier` - `applicationinsights` or `azuremonitor`
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `api_management_logger_id` - Logger ID

**Optional Arguments:**
- `sampling_percentage` - Sampling percentage (0.0-100.0)
- `always_log_errors` - Always log errors
- `log_client_ip` - Log client IP
- `verbosity` - `verbose`, `information`, or `error`
- `http_correlation_protocol` - `None`, `Legacy`, or `W3C`
- `operation_name_format` - `Name` or `Url`
- `frontend_request` - Frontend request logging
- `frontend_response` - Frontend response logging
- `backend_request` - Backend request logging
- `backend_response` - Backend response logging

**Request/Response Block:**
```hcl
frontend_request {
  body_bytes     = 32
  headers_to_log = ["content-type", "accept"]
  data_masking {
    headers {
      mode  = "Mask"
      value = "Authorization"
    }
  }
}
```

### azurerm_api_management_api_diagnostic

API-level diagnostics.

**Required Arguments:**
- `identifier` - `applicationinsights` or `azuremonitor`
- `api_name` - API name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `api_management_logger_id` - Logger ID

---

## Security Resources

### azurerm_api_management_named_value

Named value (property) for configuration.

**Required Arguments:**
- `name` - Named value name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `display_name` - Display name

**Optional Arguments:**
- `value` - Plain text value
- `value_from_key_vault` - Key Vault secret reference
- `secret` - Mark as secret (default: false)
- `tags` - Tags for filtering

**Key Vault Reference:**
```hcl
resource "azurerm_api_management_named_value" "secret" {
  name                = "my-secret"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "MySecret"
  secret              = true

  value_from_key_vault {
    secret_id = azurerm_key_vault_secret.secret.id
  }
}
```

### azurerm_api_management_certificate

Certificate for client authentication.

**Required Arguments:**
- `name` - Certificate name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name

**Optional Arguments:**
- `data` - Base64-encoded PFX certificate
- `password` - Certificate password
- `key_vault_secret_id` - Key Vault certificate ID

### azurerm_api_management_authorization_server

OAuth 2.0 authorization server.

**Required Arguments:**
- `name` - Server name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `display_name` - Display name
- `authorization_endpoint` - Authorization endpoint URL
- `client_id` - Client ID
- `client_registration_endpoint` - Registration endpoint
- `grant_types` - List of grant types

### azurerm_api_management_openid_connect_provider

OpenID Connect provider.

**Required Arguments:**
- `name` - Provider name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `display_name` - Display name
- `client_id` - Client ID
- `metadata_endpoint` - Metadata endpoint URL

---

## Gateway Resources

### azurerm_api_management_gateway

Self-hosted gateway.

**Required Arguments:**
- `name` - Gateway name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `location_data` - Location information

### azurerm_api_management_gateway_api

Link API to gateway.

**Required Arguments:**
- `gateway_id` - Gateway resource ID
- `api_id` - API ID

---

## Workspace Resources

### azurerm_api_management_workspace

APIM workspace.

**Required Arguments:**
- `name` - Workspace name
- `api_management_name` - APIM service name
- `resource_group_name` - Resource group name
- `display_name` - Display name

### azurerm_api_management_workspace_policy

Workspace-level policy.

### azurerm_api_management_workspace_policy_fragment

Workspace policy fragment.

### azurerm_api_management_workspace_certificate

Workspace certificate.

### azurerm_api_management_workspace_api_version_set

Workspace API version set.

---

## Data Sources

| Data Source | Description |
|-------------|-------------|
| `azurerm_api_management` | Get existing APIM instance |
| `azurerm_api_management_api` | Get existing API |
| `azurerm_api_management_api_version_set` | Get version set |
| `azurerm_api_management_gateway` | Get gateway |
| `azurerm_api_management_group` | Get group |
| `azurerm_api_management_product` | Get product |
| `azurerm_api_management_subscription` | Get subscription |
| `azurerm_api_management_user` | Get user |
| `azurerm_api_management_workspace` | Get workspace |

**Example:**
```hcl
data "azurerm_api_management" "existing" {
  name                = "existing-apim"
  resource_group_name = "existing-rg"
}

output "gateway_url" {
  value = data.azurerm_api_management.existing.gateway_url
}
```
