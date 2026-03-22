param apimServiceName string
param backendName string
param backendDescription string
param backendURL string
param basePath string = 'kb'

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
  name: '${basePath}-mcp'
  properties: {
    type: 'mcp'
    displayName: 'AI Search KB MCP'
    description: 'AI Search KB MCP Server'
    subscriptionRequired: true
    path: basePath
    protocols: [
      'https'
    ]
    backendId: backend.name
    mcpPropperties: {
      transportType: 'streamable'
    }
    subscriptionKeyParameterNames: {
      header: 'api_key'
      query: 'api_key'
    }
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

output apiId string = mcp.name
output apiURL string = '${apim.properties.gatewayUrl}/${mcp.properties.path}'
