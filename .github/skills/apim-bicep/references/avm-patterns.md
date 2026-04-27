# Azure Verified Modules Patterns

Patterns and best practices from Azure Verified Modules (AVM) for API Management.

## Table of Contents

- [Using AVM Modules](#using-avm-modules)
- [Service Module](#service-module)
- [API Module](#api-module)
- [Backend Module](#backend-module)
- [Subscription Module](#subscription-module)
- [Product Module](#product-module)
- [Workspace Module](#workspace-module)

---

## Using AVM Modules

Azure Verified Modules can be referenced directly from the Bicep public registry:

```bicep
module apimService 'br/public:avm/res/api-management/service:<version>' = {
  name: 'apim-deployment'
  params: {
    name: 'my-apim'
    publisherEmail: 'admin@example.com'
    publisherName: 'My Organization'
    // ... other parameters
  }
}
```

---

## Service Module

### Full APIM Service Deployment

Based on [avm/res/api-management/service](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/api-management/service)

```bicep
module apimService 'br/public:avm/res/api-management/service:<version>' = {
  name: 'apim-deployment'
  params: {
    // Required
    name: 'apim-${uniqueString(resourceGroup().id)}'
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso'
    
    // SKU
    sku: 'Premium'  // Consumption, Developer, Basic, Basicv2, Standard, Standardv2, Premium
    skuCapacity: 1
    
    // Location
    location: resourceGroup().location
    
    // Identity
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: []
    }
    
    // Networking
    virtualNetworkType: 'None'  // None, External, Internal
    publicNetworkAccess: 'Enabled'
    
    // Features
    enableDeveloperPortal: true
    
    // APIs
    apis: [
      {
        name: 'echo-api'
        displayName: 'Echo API'
        path: 'echo'
        protocols: ['https']
        subscriptionRequired: false
        policies: [
          {
            format: 'xml'
            value: '<policies><inbound><base /></inbound><backend><base /></backend><outbound><base /></outbound></policies>'
          }
        ]
      }
    ]
    
    // Backends
    backends: [
      {
        name: 'backend-1'
        url: 'https://backend.example.com'
        protocol: 'http'
      }
    ]
    
    // Products
    products: [
      {
        name: 'starter'
        displayName: 'Starter'
        description: 'Starter tier'
        subscriptionRequired: true
        approvalRequired: false
        state: 'published'
      }
    ]
    
    // Subscriptions
    subscriptions: [
      {
        name: 'test-subscription'
        displayName: 'Test Subscription'
        scope: '/apis'
      }
    ]
    
    // Diagnostics
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
        logCategoriesAndGroups: [
          { categoryGroup: 'AllLogs' }
        ]
        metricCategories: [
          { category: 'AllMetrics' }
        ]
      }
    ]
    
    // Tags
    tags: {
      Environment: 'Production'
      Application: 'API Gateway'
    }
  }
}
```

---

## API Module

### API with Operations and Policies

Based on [avm/res/api-management/service/api](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/api-management/service/api)

```bicep
module api 'br/public:avm/res/api-management/service/api:<version>' = {
  name: 'api-deployment'
  params: {
    // Required
    apiManagementServiceName: apimService.outputs.name
    name: 'my-api'
    displayName: 'My API'
    path: 'myapi'
    
    // API Settings
    description: 'My API description'
    protocols: ['https']
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    
    // Import
    format: 'openapi+json'  // openapi, openapi+json, swagger-json, wadl-xml, wsdl
    value: loadTextContent('openapi.json')
    
    // Service URL
    serviceUrl: 'https://backend.example.com'
    
    // Versioning
    apiVersion: 'v1'
    apiRevision: '1'
    isCurrent: true
    
    // Type
    type: 'http'  // http, graphql, grpc, odata, soap, websocket
    
    // Policies
    policies: [
      {
        format: 'xml'
        value: '<policies><inbound><base /><rate-limit calls="100" renewal-period="60" /></inbound><backend><base /></backend><outbound><base /></outbound></policies>'
      }
    ]
    
    // Operations
    operations: [
      {
        name: 'get-items'
        displayName: 'Get Items'
        method: 'GET'
        urlTemplate: '/items'
        description: 'Get all items'
      }
      {
        name: 'get-item'
        displayName: 'Get Item'
        method: 'GET'
        urlTemplate: '/items/{id}'
        description: 'Get item by ID'
        templateParameters: [
          {
            name: 'id'
            type: 'string'
            required: true
          }
        ]
      }
    ]
    
    // Diagnostics
    diagnostics: [
      {
        name: 'applicationinsights'
        loggerName: 'appinsights-logger'
        alwaysLog: 'allErrors'
        httpCorrelationProtocol: 'W3C'
        logClientIp: true
        metrics: true
        verbosity: 'information'
        samplingPercentage: 100
      }
    ]
  }
}
```

---

## Backend Module

### Single Backend

Based on [avm/res/api-management/service/backend](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/api-management/service/backend)

```bicep
module backend 'br/public:avm/res/api-management/service/backend:<version>' = {
  name: 'backend-deployment'
  params: {
    apiManagementServiceName: apimService.outputs.name
    name: 'my-backend'
    url: 'https://backend.example.com'
    protocol: 'http'
    description: 'My backend service'
    
    // TLS settings
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    
    // Credentials (for managed identity)
    credentials: {
      managedIdentity: {
        resource: 'https://management.azure.com'
      }
    }
    
    // Circuit breaker
    circuitBreaker: {
      rules: [
        {
          name: 'BreakerRule'
          failureCondition: {
            count: 3
            interval: 'PT1M'
            statusCodeRanges: [
              { min: 500, max: 599 }
            ]
          }
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
  }
}
```

### Backend Pool

```bicep
// Define backends first
var backendsConfig = [
  { name: 'backend-1', url: 'https://backend1.example.com', priority: 1, weight: 50 }
  { name: 'backend-2', url: 'https://backend2.example.com', priority: 1, weight: 50 }
]

// Create individual backends
module backends 'br/public:avm/res/api-management/service/backend:<version>' = [for config in backendsConfig: {
  name: 'backend-${config.name}'
  params: {
    apiManagementServiceName: apimService.outputs.name
    name: config.name
    url: config.url
    protocol: 'http'
  }
}]

// Create backend pool
module backendPool 'br/public:avm/res/api-management/service/backend:<version>' = {
  name: 'backend-pool-deployment'
  params: {
    apiManagementServiceName: apimService.outputs.name
    name: 'backend-pool'
    type: 'Pool'
    pool: {
      services: [for (config, i) in backendsConfig: {
        id: backends[i].outputs.resourceId
        priority: config.priority
        weight: config.weight
      }]
    }
  }
  dependsOn: backends
}
```

---

## Subscription Module

Based on [avm/res/api-management/service/subscription](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/api-management/service/subscription)

```bicep
module subscription 'br/public:avm/res/api-management/service/subscription:<version>' = {
  name: 'subscription-deployment'
  params: {
    apiManagementServiceName: apimService.outputs.name
    name: 'my-subscription'
    displayName: 'My Subscription'
    
    // Scope
    scope: '/apis'  // All APIs
    // scope: '/apis/${api.outputs.name}'  // Specific API
    // scope: '/products/${product.outputs.name}'  // Specific product
    
    // State
    state: 'active'  // active, suspended, submitted, rejected, cancelled, expired
    
    // Tracing
    allowTracing: true
    
    // Optional: specify keys
    // primaryKey: 'custom-key'
    // secondaryKey: 'custom-secondary-key'
  }
}
```

---

## Product Module

Based on [avm/res/api-management/service/product](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/api-management/service/product)

```bicep
module product 'br/public:avm/res/api-management/service/product:<version>' = {
  name: 'product-deployment'
  params: {
    apiManagementServiceName: apimService.outputs.name
    name: 'premium'
    displayName: 'Premium Tier'
    description: 'Premium API access with higher limits'
    
    // Subscription settings
    subscriptionRequired: true
    approvalRequired: true
    subscriptionsLimit: 10
    
    // State
    state: 'published'  // notPublished, published
    
    // Terms
    terms: 'By using this product you agree to our terms of service.'
    
    // APIs included
    apis: [
      api.outputs.name
    ]
    
    // Groups with access
    groups: [
      'developers'
      'administrators'
    ]
  }
}
```

---

## Workspace Module

Workspaces provide logical isolation within an APIM instance.

Based on [avm/res/api-management/service/workspace](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/api-management/service/workspace)

```bicep
module workspace 'br/public:avm/res/api-management/service/workspace:<version>' = {
  name: 'workspace-deployment'
  params: {
    apiManagementServiceName: apimService.outputs.name
    name: 'team-workspace'
    displayName: 'Team Workspace'
    description: 'Workspace for team APIs'
    
    // APIs in workspace
    apis: [
      {
        name: 'workspace-api'
        displayName: 'Workspace API'
        path: 'workspace/api'
        protocols: ['https']
        subscriptionRequired: false
      }
    ]
    
    // Backends in workspace
    backends: [
      {
        name: 'workspace-backend'
        url: 'https://workspace-backend.example.com'
        protocol: 'http'
      }
    ]
    
    // Products in workspace
    products: [
      {
        name: 'workspace-product'
        displayName: 'Workspace Product'
        subscriptionRequired: true
        state: 'published'
      }
    ]
    
    // Subscriptions in workspace
    subscriptions: [
      {
        name: 'workspace-subscription'
        displayName: 'Workspace Subscription'
        scope: '/apis'
      }
    ]
    
    // Gateway configuration
    gateway: {
      name: 'workspace-gateway'
      capacity: 1
      virtualNetworkType: 'None'
    }
    
    // Role assignments
    roleAssignments: [
      {
        principalId: 'user-principal-id'
        roleDefinitionIdOrName: 'API Management Workspace Contributor'
      }
    ]
  }
}
```

---

## Best Practices from AVM

### 1. Use Telemetry

AVM modules include optional telemetry. Enable it for better support:

```bicep
module apim 'br/public:avm/res/api-management/service:<version>' = {
  params: {
    enableTelemetry: true
    // ...
  }
}
```

### 2. Consistent Naming

Use consistent naming with unique suffixes:

```bicep
var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apimName = 'apim-${resourceSuffix}'
```

### 3. Parameter Validation

Use decorators for validation:

```bicep
@minLength(1)
@maxLength(50)
@description('Name of the API Management service')
param name string

@allowed(['Developer', 'Standard', 'Premium'])
param sku string = 'Developer'
```

### 4. Output Important Values

```bicep
output resourceId string = apimService.id
output name string = apimService.name
output gatewayUrl string = apimService.properties.gatewayUrl
output principalId string = apimService.identity.principalId
```

### 5. Use Existing Resources Pattern

```bicep
resource existingApim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}
```

### 6. Batch Operations

Use `@batchSize` for sequential operations:

```bicep
@batchSize(1)
resource subscriptions 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = [for sub in subscriptionsConfig: {
  // ...
}]
```
