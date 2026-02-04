# MCP Server Bicep Patterns

Patterns for deploying Model Context Protocol (MCP) servers using Azure API Management.

## Table of Contents

- [Overview](#overview)
- [Native MCP API (Tools from Operations)](#native-mcp-api-tools-from-operations)
- [Streamable MCP with Backend](#streamable-mcp-with-backend)
- [MCP with Custom Operations](#mcp-with-custom-operations)
- [MCP with Azure API Center Registration](#mcp-with-azure-api-center-registration)
- [MCP Policies](#mcp-policies)

---

## Overview

APIM supports MCP servers through the `type: 'mcp'` API type. There are two main approaches:

1. **Native MCP**: Wraps existing APIM operations as MCP tools
2. **Streamable MCP**: Proxies to an external MCP server backend

---

## Native MCP API (Tools from Operations)

Creates an MCP server that exposes existing API operations as MCP tools.

**Source**: [labs/mcp-from-api/src/weather/mcp-server/mcp.bicep](../../../../labs/mcp-from-api/src/weather/mcp-server/mcp.bicep)

```bicep
param apimServiceName string
param apiName string = 'weather-api'
param operationName string = 'get-weather'
param mcpPath string = 'weather-mcp'
param mcpName string = 'weather-mcp'
param mcpDisplayName string = 'Weather MCP'
param mcpDescription string = 'MCP for weather data'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: apiName
}

resource operation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: operationName
}

resource mcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: mcpName
  properties: {
    type: 'mcp'
    displayName: mcpDisplayName
    description: mcpDescription
    subscriptionRequired: false
    path: mcpPath
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

// Optional: Add diagnostics
resource mcpInsights 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: mcp
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apimServiceName, 'appinsights-logger')
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

// Optional: Add policy
resource policy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: mcp
  name: 'policy'
  properties: {
    value: loadTextContent('policy.xml')
    format: 'rawxml'
  }
}

output name string = mcp.name
output endpoint string = '${apim.properties.gatewayUrl}/${mcpPath}/mcp'
```

---

## Streamable MCP with Backend

Creates an MCP server that proxies to an external MCP backend service.

**Source**: [modules/apim-streamable-mcp/api.bicep](../../../../modules/apim-streamable-mcp/api.bicep)

```bicep
param apimServiceName string
param MCPServiceURL string
param MCPPath string = 'weather'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

// Create backend pointing to external MCP server
resource mcpBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: '${MCPPath}-mcp-backend'
  properties: {
    protocol: 'http'
    url: '${MCPServiceURL}/mcp'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    type: 'Single'
  }
}

// Create MCP API with streamable transport
resource mcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: '${MCPPath}-mcp-tools'
  properties: {
    displayName: '${MCPPath} MCP Tools'
    type: 'mcp'
    subscriptionRequired: false
    backendId: mcpBackend.name
    path: MCPPath
    protocols: ['https']
    mcpProperties: {
      transportType: 'streamable'
    }
    authenticationSettings: {
      oAuth2AuthenticationSettings: []
      openidAuthenticationSettings: []
    }
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'subscription-key'
    }
    isCurrent: true
  }
}

// Add policy for backend routing
resource APIPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: mcp
  name: 'policy'
  properties: {
    value: loadTextContent('policy.xml')
    format: 'rawxml'
  }
}
```

### Alternative: Streamable MCP with Backend ID Reference

**Source**: [labs/mcp-client-authorization/src/weather/apim-mcp-server/mcp.bicep](../../../../labs/mcp-client-authorization/src/weather/apim-mcp-server/mcp.bicep)

```bicep
param apimServiceName string
param backendName string
param backendDescription string
param backendURL string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource backend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: backendName
  properties: {
    description: backendDescription
    url: backendURL
    protocol: 'http'
  }
}

resource mcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'weather-mcp'
  properties: {
    type: 'mcp'
    displayName: 'Weather MCP'
    description: 'Weather MCP Server'
    subscriptionRequired: false
    path: 'weather-mcp'
    protocols: ['https']
    backendId: backend.name
    mcpPropperties: {
      transportType: 'streamable'
    }
  }
}
```

---

## MCP with Custom Operations

Creates an MCP-compatible API with custom SSE and message endpoints.

**Source**: [labs/mcp-a2a-agents/src/mcp_sk_servers/apim-mcp/mcp-api.bicep](../../../../labs/mcp-a2a-agents/src/mcp_sk_servers/apim-mcp/mcp-api.bicep)

```bicep
@description('The name of the API Management service')
param apimServiceName string

@description('The URL of the container app hosting MCP endpoints')
param acaContainerAppURL string

@description('Path for MCP Agent API')
param APIPath string

@description('MCP Agent Name')
param agentName string

resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimServiceName
}

// Create the MCP API definition
resource mcpApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apimService
  name: agentName
  properties: {
    displayName: '${agentName} Server'
    description: 'Model Context Protocol API endpoints'
    subscriptionRequired: false
    path: APIPath
    protocols: ['https']
    serviceUrl: acaContainerAppURL
  }
}

// SSE endpoint for real-time events
resource mcpSseOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-sse'
  properties: {
    displayName: 'MCP SSE Endpoint'
    method: 'GET'
    urlTemplate: '/sse'
    description: 'Server-Sent Events endpoint for MCP Server'
  }
}

// Message endpoint for client messages
resource mcpMessageOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-message'
  properties: {
    displayName: 'MCP Message Endpoint'
    method: 'POST'
    urlTemplate: '/message'
    description: 'Message endpoint for MCP Server'
  }
}

// Streamable endpoint
resource mcpStreamableOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-streamable'
  properties: {
    displayName: 'MCP Streamable Endpoint'
    method: 'POST'
    urlTemplate: '/mcp'
    description: 'Streamable endpoint for MCP Server'
  }
}

output apiId string = mcpApi.id
```

---

## MCP with Azure API Center Registration

Registers the MCP server in Azure API Center for discovery.

**Source**: [labs/mcp-from-api/src/weather/mcp-server/mcp.bicep](../../../../labs/mcp-from-api/src/weather/mcp-server/mcp.bicep)

```bicep
param apimServiceName string
param apicServiceName string
param mcpName string = 'weather-mcp'
param mcpPath string = 'weather-mcp'
param mcpDisplayName string = 'Weather MCP'
param mcpDescription string = 'MCP for weather data'
param environmentName string
param mcpLifecycleStage string = 'development'
param mcpVersionName string = '1-0-0'
param mcpVersionDisplayName string = '1.0.0'

// APIM MCP API (as shown above)
resource mcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  // ... MCP API definition
}

// API Center resources
resource apiCenterService 'Microsoft.ApiCenter/services@2024-06-01-preview' existing = {
  name: apicServiceName
}

resource apiCenterWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-06-01-preview' existing = {
  parent: apiCenterService
  name: 'default'
}

// Register MCP in API Center
resource apiCenterMCP 'Microsoft.ApiCenter/services/workspaces/apis@2024-06-01-preview' = {
  parent: apiCenterWorkspace
  name: mcpName
  properties: {
    title: mcpDisplayName
    kind: 'mcp'
    lifecycleState: mcpLifecycleStage
    externalDocumentation: [
      {
        description: mcpDescription
        title: mcpDisplayName
        url: 'https://example.com/mcp-docs'
      }
    ]
    contacts: []
    customProperties: {}
    summary: mcpDescription
    description: mcpDescription
  }
}

// Add API Version
resource mcpVersion 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-06-01-preview' = {
  parent: apiCenterMCP
  name: mcpVersionName
  properties: {
    title: mcpVersionDisplayName
    lifecycleStage: mcpLifecycleStage
  }
}

// Add API Definition
resource mcpDefinition 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-06-01-preview' = {
  parent: mcpVersion
  name: '${mcpName}-definition'
  properties: {
    description: '${mcpDisplayName} Definition'
    title: '${mcpDisplayName} Definition'
  }
}

// Add API Deployment
resource mcpDeployment 'Microsoft.ApiCenter/services/workspaces/apis/deployments@2024-06-01-preview' = {
  parent: apiCenterMCP
  name: '${mcpName}-deployment'
  properties: {
    description: '${mcpDisplayName} Deployment'
    title: '${mcpDisplayName} Deployment'
    environmentId: '/workspaces/default/environments/${environmentName}'
    definitionId: '/workspaces/${apiCenterWorkspace.name}/apis/${apiCenterMCP.name}/versions/${mcpVersion.name}/definitions/${mcpDefinition.name}'
    state: 'active'
    server: {
      runtimeUri: [
        '${apim.properties.gatewayUrl}/${mcpPath}'
      ]
    }
  }
}

output endpoint string = '${apim.properties.gatewayUrl}/${mcpPath}/mcp'
```

---

## MCP Policies

### Basic MCP Policy

```xml
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="{backend-id}" />
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
```

### MCP Policy with Managed Identity Authentication

```xml
<policies>
    <inbound>
        <base />
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" 
            output-token-variable-name="managed-id-access-token" ignore-error="false" />
        <set-header name="Authorization" exists-action="override">
            <value>@("Bearer " + (string)context.Variables["managed-id-access-token"])</value>
        </set-header>
        <set-backend-service backend-id="{backend-id}" />
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
```

### Important Notes for MCP Policies

⚠️ **Warning**: Do not access the response body using `context.Response.Body` within MCP server policies. Doing so triggers response buffering, which interferes with the streaming behavior required by MCP servers and may cause them to malfunction.

```bicep
// In diagnostics, avoid logging response body for MCP APIs
resource mcpInsights 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: mcp
  properties: {
    // ...
    frontend: {
      // request: logSettings  // OK to log
      // response: logSettings  // AVOID for MCP - breaks streaming
    }
    backend: {
      // request: logSettings  // OK to log
      // response: logSettings  // AVOID for MCP - breaks streaming
    }
  }
}
```
