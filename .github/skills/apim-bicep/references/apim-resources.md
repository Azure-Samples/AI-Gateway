# APIM Bicep Resource Reference

Complete reference for Azure API Management Bicep resources.

## Table of Contents

- [Service Instance](#service-instance)
- [APIs](#apis)
- [Operations](#operations)
- [Backends](#backends)
- [Subscriptions](#subscriptions)
- [Products](#products)
- [Loggers](#loggers)
- [Diagnostics](#diagnostics)
- [Named Values](#named-values)
- [Role Assignments](#role-assignments)

---

## Service Instance

### Microsoft.ApiManagement/service

```bicep
@description('The name of the API Management service')
param apiManagementServiceName string = 'apim-${uniqueString(resourceGroup().id)}'

@description('Publisher email address')
param publisherEmail string

@description('Publisher name')
param publisherName string

@description('SKU of the API Management service')
@allowed(['Consumption', 'Developer', 'Basic', 'Basicv2', 'Standard', 'Standardv2', 'Premium'])
param sku string = 'Basicv2'

@description('SKU capacity (units)')
param skuCount int = 1

@description('Location for all resources')
param location string = resourceGroup().location

@description('Managed identity type')
@allowed(['None', 'SystemAssigned', 'UserAssigned', 'SystemAssigned, UserAssigned'])
param identityType string = 'SystemAssigned'

@description('Release channel for preview features')
@allowed(['Early', 'Default', 'Late', 'GenAI'])
param releaseChannel string = 'Default'

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: sku
    capacity: skuCount
  }
  identity: {
    type: identityType
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    releaseChannel: releaseChannel
    // Optional properties
    virtualNetworkType: 'None'  // or 'External', 'Internal'
    publicNetworkAccess: 'Enabled'
  }
}

output id string = apimService.id
output name string = apimService.name
output gatewayUrl string = apimService.properties.gatewayUrl
output principalId string = apimService.identity.principalId
```

### Diagnostic Settings for APIM Service

```bicep
resource apimDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apimService
  name: 'apimDiagnosticSettings'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
```

---

## APIs

### Microsoft.ApiManagement/service/apis

#### HTTP API with OpenAPI Spec

```bicep
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'my-api'
  parent: apimService
  properties: {
    displayName: 'My API'
    description: 'API Description'
    path: 'api/v1'
    protocols: ['https']
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    // Import from OpenAPI
    format: 'openapi+json'  // or 'openapi', 'swagger-json', 'swagger-link-json', 'wadl-xml', 'wadl-link-json', 'wsdl', 'wsdl-link'
    value: string(loadJsonContent('./openapi.json'))
    // Versioning
    apiVersion: 'v1'
    apiRevision: '1'
    isCurrent: true
  }
}
```

#### API with Service URL

```bicep
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'simple-api'
  parent: apimService
  properties: {
    displayName: 'Simple API'
    description: 'Simple API with backend URL'
    path: 'simple'
    protocols: ['https']
    subscriptionRequired: false
    serviceUrl: 'https://backend.example.com'
  }
}
```

#### MCP API (Model Context Protocol)

```bicep
resource mcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apimService
  name: 'weather-mcp'
  properties: {
    type: 'mcp'
    displayName: 'Weather MCP'
    description: 'Weather MCP Server'
    subscriptionRequired: false
    path: 'weather'
    protocols: ['https']
    // For native MCP with tools from existing operations
    mcpTools: [
      {
        name: 'get-weather'
        operationId: existingOperation.id
        description: 'Get weather for a location'
      }
    ]
    // OR for streamable MCP with backend
    backendId: mcpBackend.name
    mcpProperties: {
      transportType: 'streamable'
    }
  }
}
```

---

## Operations

### Microsoft.ApiManagement/service/apis/operations

```bicep
resource operation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: api
  name: 'get-items'
  properties: {
    displayName: 'Get Items'
    method: 'GET'
    urlTemplate: '/items'
    description: 'Retrieve all items'
    // Request parameters
    templateParameters: []
    request: {
      queryParameters: [
        {
          name: 'filter'
          type: 'string'
          description: 'Filter expression'
          required: false
        }
      ]
      headers: []
    }
    // Response definitions
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}
```

### Operation with Path Parameters

```bicep
resource operationWithParams 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: api
  name: 'get-item-by-id'
  properties: {
    displayName: 'Get Item by ID'
    method: 'GET'
    urlTemplate: '/items/{id}'
    description: 'Retrieve item by ID'
    templateParameters: [
      {
        name: 'id'
        type: 'string'
        required: true
        description: 'Item identifier'
      }
    ]
  }
}
```

---

## Backends

### Microsoft.ApiManagement/service/backends

#### Single Backend

```bicep
resource backend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'my-backend'
  parent: apimService
  properties: {
    description: 'My backend service'
    url: 'https://my-backend.azurewebsites.net'
    protocol: 'http'
    type: 'Single'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}
```

#### Backend with Managed Identity

```bicep
resource aiBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'openai-backend'
  parent: apimService
  properties: {
    description: 'Azure OpenAI backend'
    url: 'https://my-openai.openai.azure.com/openai'
    protocol: 'http'
    credentials: {
      managedIdentity: {
        resource: 'https://cognitiveservices.azure.com'
      }
    }
  }
}
```

#### Backend with Circuit Breaker

```bicep
resource backendWithCircuitBreaker 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'resilient-backend'
  parent: apimService
  properties: {
    description: 'Backend with circuit breaker'
    url: 'https://backend.example.com'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          name: 'BreakerRule'
          failureCondition: {
            count: 3
            interval: 'PT1M'
            statusCodeRanges: [
              { min: 500, max: 599 }
              { min: 429, max: 429 }
            ]
            errorReasons: ['Server errors']
          }
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
  }
}
```

#### Backend Pool (Load Balancing)

```bicep
// Create individual backends first
resource backends 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = [for (config, i) in backendsConfig: {
  name: config.name
  parent: apimService
  properties: {
    description: 'Backend ${config.name}'
    url: config.url
    protocol: 'http'
  }
}]

// Create backend pool
resource backendPool 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'backend-pool'
  parent: apimService
  properties: {
    description: 'Load balanced backend pool'
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

---

## Subscriptions

### Microsoft.ApiManagement/service/subscriptions

```bicep
@batchSize(1)
resource subscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = [for sub in subscriptionsConfig: {
  name: sub.name
  parent: apimService
  properties: {
    displayName: sub.displayName
    scope: sub.?scope ?? '/apis'  // '/apis', '/apis/{apiId}', '/products/{productId}'
    state: 'active'  // 'active', 'suspended', 'submitted', 'rejected', 'cancelled', 'expired'
    allowTracing: true
    // Optional: specify keys
    // primaryKey: 'custom-primary-key'
    // secondaryKey: 'custom-secondary-key'
  }
}]

// Get subscription key
#disable-next-line outputs-should-not-contain-secrets
output subscriptionKey string = subscription[0].listSecrets().primaryKey
```

---

## Products

### Microsoft.ApiManagement/service/products

```bicep
resource product 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  name: 'premium-tier'
  parent: apimService
  properties: {
    displayName: 'Premium Tier'
    description: 'Premium API access'
    subscriptionRequired: true
    approvalRequired: true
    subscriptionsLimit: 10
    state: 'published'  // 'notPublished', 'published'
    terms: 'Terms of service...'
  }
}

// Link API to product
resource productApi 'Microsoft.ApiManagement/service/products/apis@2024-06-01-preview' = {
  name: api.name
  parent: product
}
```

---

## Loggers

### Microsoft.ApiManagement/service/loggers

#### Azure Monitor Logger

```bicep
resource azureMonitorLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apimService
  name: 'azuremonitor'
  properties: {
    loggerType: 'azureMonitor'
    isBuffered: false
  }
}
```

#### Application Insights Logger

```bicep
resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  name: 'appinsights-logger'
  parent: apimService
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights Logger'
    isBuffered: false
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    resourceId: appInsightsResourceId
  }
}
```

#### Event Hub Logger

```bicep
resource eventHubLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  name: 'eventhub-logger'
  parent: apimService
  properties: {
    loggerType: 'azureEventHub'
    description: 'Event Hub Logger'
    isBuffered: true
    credentials: {
      name: eventHubName
      connectionString: eventHubConnectionString
    }
  }
}
```

---

## Diagnostics

### Microsoft.ApiManagement/service/apis/diagnostics

#### Standard API Diagnostics

```bicep
resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: api
  name: 'applicationinsights'  // or 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: appInsightsLogger.id
    verbosity: 'verbose'  // 'verbose', 'information', 'error'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: ['Content-Type', 'User-Agent']
        body: { bytes: 8192 }
      }
      response: {
        headers: ['Content-Type']
        body: { bytes: 8192 }
      }
    }
    backend: {
      request: {
        headers: ['Content-Type']
        body: { bytes: 8192 }
      }
      response: {
        headers: ['Content-Type']
        body: { bytes: 8192 }
      }
    }
  }
}
```

#### LLM API Diagnostics (for AI Gateway)

```bicep
resource llmApiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: api
  name: 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: azureMonitorLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    largeLanguageModel: {
      logs: 'enabled'
      requests: {
        messages: 'all'  // 'all', 'none'
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

---

## Named Values

### Microsoft.ApiManagement/service/namedValues

```bicep
resource namedValue 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  name: 'backend-url'
  parent: apimService
  properties: {
    displayName: 'BackendUrl'
    value: 'https://backend.example.com'
    secret: false
    tags: ['environment', 'config']
  }
}

// Secret named value with Key Vault
resource secretNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  name: 'api-secret'
  parent: apimService
  properties: {
    displayName: 'ApiSecret'
    secret: true
    keyVault: {
      secretIdentifier: 'https://myvault.vault.azure.net/secrets/my-secret'
      identityClientId: userAssignedIdentityClientId  // optional
    }
  }
}
```

---

## Role Assignments

### Assign RBAC Roles to APIM Managed Identity

```bicep
var azureRoles = loadJsonContent('../../azure-roles.json')
var cognitiveServicesUserRole = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesUser)

resource cognitiveServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cognitiveServicesAccount.id, apimService.id, cognitiveServicesUserRole)
  scope: cognitiveServicesAccount
  properties: {
    roleDefinitionId: cognitiveServicesUserRole
    principalId: apimService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
```

### Common Azure Role IDs

```json
{
  "CognitiveServicesUser": "a97b65f3-24c7-4388-baec-2e87135dc908",
  "CognitiveServicesContributor": "25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68",
  "Contributor": "b24988ac-6180-42a0-ab88-20f7382dd24c",
  "Reader": "acdd72a7-3385-48ef-bd42-f606fba81ae7"
}
```
