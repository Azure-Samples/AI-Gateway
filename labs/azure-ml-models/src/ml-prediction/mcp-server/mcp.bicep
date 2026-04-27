param apimServiceName string
param apiName string = 'ml-prediction-api'
param operationName string = 'predict-forecast'

param mcpPath string = 'ml-prediction-mcp'
param mcpName string = 'ml-prediction-mcp'
param mcpDisplayName string = 'ML Prediction MCP'
param mcpDescription string = 'MCP server for invoking an Azure ML forecasting model. Provides a predict-forecast tool that accepts a distributor ID and delivery date to return delivery quantity predictions.'

// ------------------
//    RESOURCES
// ------------------

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
    frontend: {}
    backend: {}
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

// ------------------
//    OUTPUTS
// ------------------

output name string = mcp.name
output endpoint string = '${apim.properties.gatewayUrl}/${mcpPath}/mcp'
