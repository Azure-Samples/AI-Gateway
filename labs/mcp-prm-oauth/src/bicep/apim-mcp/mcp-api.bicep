@description('The name of the API Management service')
param apimServiceName string

@description('The name of the Container App hosting the MCP endpoints')
param webAppName string

@description('The ID of the MCP Entra application')
param mcpAppId string

@description('The tenant ID of the MCP Entra application')
param mcpAppTenantId string

@description('MCP API path to be served via APIM')
param mcpApiPath string = 'mcp'

// Get reference to the existing APIM service
resource apimService 'Microsoft.ApiManagement/service@2025-09-01-preview' existing = {
  name: apimServiceName
}

resource dynamicDiscovery 'Microsoft.ApiManagement/service/apis@2025-09-01-preview' existing = {
  parent: apimService
  name: 'mcp-prm-dynamic-discovery'
}

// Get reference to the Container App
resource containerApp 'Microsoft.App/containerApps@2023-11-02-preview' existing = {
  name: webAppName
}


// Create or update named values for MCP OAuth configuration
resource mcpTenantIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpTenantId'
  properties: {
    displayName: 'McpTenantId'
    value: mcpAppTenantId
    secret: false
  }
}

resource mcpClientIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpClientId'
  properties: {
    displayName: 'McpClientId'
    value: mcpAppId
    secret: false
  }
}

// Create or update the APIM Gateway URL named value
resource APIMGatewayURLNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'APIMGatewayURL'
  properties: {
    displayName: 'APIMGatewayURL'
    value: apimService.properties.gatewayUrl
    secret: false
  }
}

resource mcpApiPathNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpApiPath'
  properties: {
    displayName: 'McpApiPath'
    value: mcpApiPath
    secret: false
  }
}

resource mcpBackendServerUrl 'Microsoft.ApiManagement/service/backends@2025-09-01-preview' = {
  parent: apimService
  name: '${webAppName}-mcp-backend'
  properties: {
    url: 'https://${containerApp.properties.configuration.ingress.fqdn}'
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    type: 'Single'
  }
}

// Create the MCP Passthrough definition in APIM
resource mcpApi 'Microsoft.ApiManagement/service/apis@2025-09-01-preview' = {
  parent: apimService
  name: '${webAppName}-mcp-server'
  properties: {
    displayName: '${webAppName} MCP Server'
    type: 'mcp'
    subscriptionRequired: false
    backendId: mcpBackendServerUrl.name
    description: 'MCP API for ${webAppName} retrieving authenticated account Graph info'
    path: mcpApiPath    
    protocols: ['https']
    mcpProperties: {
      endpoints : {
        mcp: {
          uriTemplate: '/mcp'
        }
      }
    }
    authenticationSettings: {
      oAuth2AuthenticationSettings: []
      openidAuthenticationSettings: []
    }
    isCurrent: true
  }
}

// Apply policy at the API level for all operations
resource mcpApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2025-09-01-preview' = {
  parent: mcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-api.policy.xml')
  }
  dependsOn: [
    APIMGatewayURLNamedValue
    mcpTenantIdNamedValue
    mcpClientIdNamedValue
  ]
}

// Create the PRM (Protected Resource Metadata in the global discovery) endpoint - RFC 9728
resource mcpPrmDiscoveryOperation 'Microsoft.ApiManagement/service/apis/operations@2025-09-01-preview' = {
  parent: dynamicDiscovery
  name: 'mcp-prm-discovery-operation'
  properties: {
    displayName: 'Protected Resource Metadata'
    method: 'GET'
    urlTemplate: '/${mcpApiPath}/mcp'
    description: 'Protected Resource Metadata endpoint (RFC 9728)'
  }
}

// Apply specific policy for the PRM endpoint (anonymous access)
resource mcpPrmGlobalPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2025-09-01-preview' = {
  parent: mcpPrmDiscoveryOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-prm.policy.xml')
  }
  dependsOn: [
    APIMGatewayURLNamedValue
    mcpTenantIdNamedValue
    mcpClientIdNamedValue
  ]
}

// Output the API ID for reference
output apiId string = mcpApi.id
output mcpAppId string = mcpAppId
output mcpAppTenantId string = mcpAppTenantId
