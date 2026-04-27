param apimServiceName string
param apicServiceName string
param apiName string = 'catalog-api'
param operationName string = 'get-product-details'

param mcpPath string = 'catalog-mcp'
param mcpName string = 'catalog-mcp'
param mcpDisplayName string = 'Product Catalog MCP'
param mcpDescription string = 'MCP for product catalog data'

param environmentName string
param mcpLifecycleStage string = 'development'

param mcpVersionName string = '1-0-0'
param mcpVersionDisplayName string = '1.0.0'
param mcpDefinitionName string = '${mcpName}-definition'
param mcpDefinitionDisplayName string = '${mcpDisplayName} Definition'
param mcpDefinitionDescription string = '${mcpDisplayName} Definition for version ${mcpVersionName}'

param mcpDeploymentName string = '${mcpName}-deployment'
param mcpDeploymentDisplayName string = '${mcpDisplayName} Deployment'
param mcpDeploymentDescription string = '${mcpDisplayName} Deployment for version ${mcpVersionName} and environment ${environmentName}'


resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource operation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: operationName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing =  {
  parent: apim
  name: apiName
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
    protocols: [
      'https'
    ]
    mcpTools: [
      {
        name: operation.name
        operationId: operation.id
        description: operation.properties.description
      }
    ]
  }
}

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

resource policy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: mcp
  name: 'policy'
  properties: {
    value: loadTextContent('policy.xml')
    format: 'rawxml'
  }
}

resource apiCenterService 'Microsoft.ApiCenter/services@2024-06-01-preview' existing = {
  name: apicServiceName
}

resource apiCenterWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-06-01-preview' existing = {
  parent: apiCenterService
  name: 'default'
}

// Add API resources using a loop
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
    contacts: [
    ]
    customProperties: {}
    summary: mcpDescription
    description: mcpDescription
  }
}

// Add API Version resources using a loop
resource mcpVersion 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-06-01-preview' = {
  parent: apiCenterMCP
  name: mcpVersionName
  properties: {
    title: mcpVersionDisplayName
    lifecycleStage: mcpLifecycleStage
  }
}

// Add API Definition resource
resource mcpDefinition 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-06-01-preview' = {
  parent: mcpVersion
  name: mcpDefinitionName
  properties: {
    description: mcpDefinitionDescription
    title: mcpDefinitionDisplayName
  }
}

// Add API Deployment resource
resource mcpDeployment 'Microsoft.ApiCenter/services/workspaces/apis/deployments@2024-06-01-preview' = {
  parent: apiCenterMCP
  name: mcpDeploymentName
  properties: {
    description: mcpDeploymentDescription
    title: mcpDeploymentDisplayName
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

// ------------------
//    OUTPUTS
// ------------------

output name string = mcp.name
output endpoint string = '${apim.properties.gatewayUrl}/${mcpPath}/mcp'
