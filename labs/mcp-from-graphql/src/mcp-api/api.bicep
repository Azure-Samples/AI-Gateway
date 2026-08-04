param apimServiceName string
param apimLoggerId string = ''
param backendName string = 'countries-mcp-backend'
param backendDescription string = 'Countries GraphQL MCP backend'
param backendUrl string
param mcpAPIPath string = 'countries-mcp'

resource apimService 'Microsoft.ApiManagement/service@2025-09-01-preview' existing = {
  name: apimServiceName
}

resource backend 'Microsoft.ApiManagement/service/backends@2025-09-01-preview' = {
  parent: apimService
  name: backendName
  properties: {
    description: backendDescription
    url: backendUrl
    protocol: 'http'
  }
}

resource mcpAPI 'Microsoft.ApiManagement/service/apis@2025-09-01-preview' = {
  parent: apimService
  name: 'countries-mcp-api'
  properties: {
    type: 'mcp'
    displayName: 'Countries MCP Server'
    description: 'GraphQL country queries exposed as MCP tools by graphql-mcp.'
    path: mcpAPIPath
    protocols: [
      'https'
    ]
    backendId: backend.name
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'subscription-key'
    }
    mcpProperties: {
      transportType: 'streamable'
      #disable-next-line BCP036 // The live APIM contract requires a dictionary keyed by endpoint name; the Bicep type still declares an array.
      endpoints: {
        message: {
          uriTemplate: '/mcp'
        }
      }
    }
  }
}

resource mcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2025-09-01-preview' = {
  parent: mcpAPI
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('policy.xml')
  }
}

resource mcpDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = if (!empty(apimLoggerId)) {
  parent: mcpAPI
  name: 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: apimLoggerId
    sampling: {
      samplingType: 'fixed'
      percentage: json('100')
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
  }
}

output name string = mcpAPI.name
output endpoint string = '${apimService.properties.gatewayUrl}/${mcpAPIPath}/mcp'
