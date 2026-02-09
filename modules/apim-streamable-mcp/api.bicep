param apimServiceName string
param MCPServiceURL string
param MCPPath string = 'weather'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource mcpBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' ={
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

resource mcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: '${MCPPath}-mcp-tools'
  properties: {
    displayName: '${MCPPath} MCP Tools'
    type: 'mcp'
    subscriptionRequired: false
    backendId: mcpBackend.name
    path: MCPPath
    protocols: [
      'https'
    ]
    mcpProperties:{
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

resource APIPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: mcp
  name: 'policy'
  properties: {
    value: loadTextContent('policy.xml')
    format: 'rawxml'
  }
}



