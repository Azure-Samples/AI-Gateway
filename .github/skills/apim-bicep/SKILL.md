---
name: apim-bicep
description: Guide for building Bicep files for Azure API Management (APIM) and related Azure services. Use when users want to create, modify, or understand Bicep templates for APIM instances, APIs, backends, subscriptions, policies, products, loggers, diagnostics, and MCP servers. This skill provides Bicep syntax, patterns from Azure Verified Modules, and examples from this repository.
---

# APIM Bicep

This skill provides guidance for creating Azure Bicep templates for API Management and related services.

## Quick Start - Basic APIM Instance

```bicep
@description('The name of the API Management service instance')
param apiManagementServiceName string = 'apim-${uniqueString(resourceGroup().id)}'

@description('The email address of the publisher')
param publisherEmail string

@description('The name of the publisher')
param publisherName string

@description('The pricing tier of this API Management service')
@allowed(['Consumption', 'Developer', 'Basic', 'Basicv2', 'Standard', 'Standardv2', 'Premium'])
param sku string = 'Basicv2'

@description('Location for all resources')
param location string = resourceGroup().location

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: sku
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

output apimId string = apimService.id
output apimName string = apimService.name
output gatewayUrl string = apimService.properties.gatewayUrl
output principalId string = apimService.identity.principalId
```

## Resource Types Reference

| Resource Type | API Version | Purpose |
|---------------|-------------|---------|
| `Microsoft.ApiManagement/service` | `2024-06-01-preview` | APIM service instance |
| `Microsoft.ApiManagement/service/apis` | `2024-06-01-preview` | API definitions |
| `Microsoft.ApiManagement/service/apis/operations` | `2024-06-01-preview` | API operations |
| `Microsoft.ApiManagement/service/apis/policies` | `2024-06-01-preview` | API-level policies |
| `Microsoft.ApiManagement/service/backends` | `2024-06-01-preview` | Backend services |
| `Microsoft.ApiManagement/service/subscriptions` | `2024-06-01-preview` | API subscriptions |
| `Microsoft.ApiManagement/service/products` | `2024-06-01-preview` | API products |
| `Microsoft.ApiManagement/service/loggers` | `2024-06-01-preview` | Logging configuration |
| `Microsoft.ApiManagement/service/apis/diagnostics` | `2024-06-01-preview` | API diagnostics |

## Essential Patterns

### Backend with Managed Identity

```bicep
resource backend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'my-backend'
  parent: apimService
  properties: {
    description: 'Backend with managed identity auth'
    url: 'https://my-service.azure.com'
    protocol: 'http'
    credentials: {
      managedIdentity: {
        resource: 'https://cognitiveservices.azure.com'
      }
    }
  }
}
```

### Backend Pool (Load Balancing)

```bicep
resource backendPool 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'inference-backend-pool'
  parent: apimService
  properties: {
    description: 'Load balancer for multiple backends'
    type: 'Pool'
    pool: {
      services: [for (config, i) in backendsConfig: {
        id: '/backends/${backends[i].name}'
        priority: config.?priority ?? 1
        weight: config.?weight ?? 1
      }]
    }
  }
}
```

### API with OpenAPI Spec

```bicep
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'my-api'
  parent: apimService
  properties: {
    displayName: 'My API'
    description: 'API description'
    path: 'api/v1'
    protocols: ['https']
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    format: 'openapi+json'
    value: string(loadJsonContent('./openapi.json'))
  }
}
```

### API Policy from File

```bicep
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: loadTextContent('policy.xml')
  }
}
```

### Subscription

```bicep
@batchSize(1)
resource subscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = [for sub in subscriptionsConfig: {
  name: sub.name
  parent: apimService
  properties: {
    displayName: sub.displayName
    scope: '/apis'  // or '/apis/{apiId}' or '/products/{productId}'
    state: 'active'
    allowTracing: true
  }
}]
```

## MCP Server Patterns

### Native MCP API (type: 'mcp')

Create an MCP server API that wraps existing API operations:

```bicep
resource mcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'weather-mcp'
  properties: {
    type: 'mcp'
    displayName: 'Weather MCP'
    description: 'MCP for weather data'
    subscriptionRequired: false
    path: 'weather-mcp'
    protocols: ['https']
    mcpTools: [
      {
        name: operation.name
        operationId: operation.id
        description: operation.properties.description
      }
    ]
  }
}
```

### Streamable MCP with Backend

Create an MCP server with a backend service:

```bicep
resource mcpBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'weather-mcp-backend'
  properties: {
    protocol: 'http'
    url: '${mcpServiceUrl}/mcp'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    type: 'Single'
  }
}

resource mcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'weather-mcp'
  properties: {
    type: 'mcp'
    displayName: 'Weather MCP'
    subscriptionRequired: false
    backendId: mcpBackend.name
    path: 'weather'
    protocols: ['https']
    mcpProperties: {
      transportType: 'streamable'
    }
  }
}
```

### MCP with Custom Operations

```bicep
resource mcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apimService
  name: 'agent-mcp'
  properties: {
    displayName: 'Agent MCP Server'
    description: 'Model Context Protocol API endpoints'
    subscriptionRequired: false
    path: 'agent'
    protocols: ['https']
    serviceUrl: containerAppUrl
  }
}

resource mcpSseOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: mcpApi
  name: 'mcp-sse'
  properties: {
    displayName: 'MCP SSE Endpoint'
    method: 'GET'
    urlTemplate: '/sse'
    description: 'Server-Sent Events endpoint'
  }
}

resource mcpMessageOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: mcpApi
  name: 'mcp-message'
  properties: {
    displayName: 'MCP Message Endpoint'
    method: 'POST'
    urlTemplate: '/message'
    description: 'Message endpoint for MCP Server'
  }
}
```

## Diagnostics and Logging

### Azure Monitor Logger

```bicep
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apimService
  name: 'azuremonitor'
  properties: {
    loggerType: 'azureMonitor'
    isBuffered: false
  }
}
```

### Application Insights Logger

```bicep
resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  name: 'appinsights-logger'
  parent: apimService
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    description: 'APIM Logger for Application Insights'
    isBuffered: false
    resourceId: appInsightsId
  }
}
```

### API Diagnostics with LLM Logging

```bicep
resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: api
  name: 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: apimLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    largeLanguageModel: {
      logs: 'enabled'
      requests: {
        messages: 'all'
        maxSizeInBytes: 262144
      }
      responses: {
        messages: 'all'
        maxSizeInBytes: 262144
      }
    }
  }
}
```

## Bicep Best Practices

### Use Existing Resources

```bicep
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}
```

### Parameter Validation

```bicep
@description('The pricing tier')
@allowed(['Consumption', 'Developer', 'Basic', 'Basicv2', 'Standard', 'Standardv2', 'Premium'])
param sku string = 'Basicv2'

@minLength(1)
@maxLength(50)
param apiManagementName string
```

### Load External Content

```bicep
// Load JSON for OpenAPI specs
value: string(loadJsonContent('./specs/openapi.json'))

// Load XML for policies
value: loadTextContent('policy.xml')

// Load and parameterize policy
var updatedPolicy = replace(loadTextContent('policy.xml'), '{backend-id}', backendName)
```

### Output Secrets Safely

```bicep
#disable-next-line outputs-should-not-contain-secrets
output subscriptionKey string = subscription.listSecrets().primaryKey
```

## Reference Documentation

For detailed patterns and examples, see:

- **[APIM Resource Reference](references/apim-resources.md)**: Complete resource definitions
- **[MCP Server Patterns](references/mcp-patterns.md)**: MCP configuration examples
- **[Azure Verified Modules](references/avm-patterns.md)**: Patterns from Azure Verified Modules

## Official Documentation

- [APIM Bicep Quickstart](https://learn.microsoft.com/en-us/azure/api-management/quickstart-bicep)
- [ARM Template Reference](https://learn.microsoft.com/en-us/azure/templates/microsoft.apimanagement/service)
- [Azure Verified Modules - APIM](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/api-management)
