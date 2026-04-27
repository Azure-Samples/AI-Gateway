// Template for registering a single MCP server
// This template can register any individual MCP server by passing the configuration as parameters

// ------------------
//    PARAMETERS  
// ------------------

@description('Name of the existing API Center to use')
param apiCenterName string

@description('Name of the MCP server')
param mcpName string

@description('Description of the MCP server')
param mcpDescription string

@description('Transport URL for the MCP server (from remotes[0].url)')
param transportURL string

@description('Documentation URL for the MCP server')
param documentationURL string

@description('Documentation title for the MCP server')
param documentationTitle string

@description('Documentation description for the MCP server')
param documentationDescription string

// ------------------
//    VARIABLES
// ------------------

// Reference existing API Center Service
resource apiCenterService 'Microsoft.ApiCenter/services@2024-03-01' existing = {
  name: apiCenterName
}

// Use default workspace
resource apiCenterWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-03-01' = {
  parent: apiCenterService
  name: 'default'
  properties: {
    title: 'Default workspace'
    description: 'Default workspace'
  }
}

// Add environment resource
resource apiEnvironment 'Microsoft.ApiCenter/services/workspaces/environments@2024-03-01' = {
  parent: apiCenterWorkspace
  name: 'mcp'
  properties: {
    title: 'mcp'
    description: 'mcp default environment'
    kind: 'mcp'
    server: {
      managementPortalUri: [
        'https://apim-rocks.azure-api.net/'
      ]
      type: 'other'
    }
  }
}

// Add single API resource
resource apiCenterAPI 'Microsoft.ApiCenter/services/workspaces/apis@2024-03-01' = {
  parent: apiCenterWorkspace
  name: mcpName
  properties: {
    title: '${toUpper(substring(mcpName, 0, 1))}${substring(mcpName, 1)}'
    kind: 'mcp'
    externalDocumentation: documentationURL != '' ? [
      {
        description: 'Install VS Code'
        title: 'Install VS Code'
        url: 'vscode:mcp/install?{"name":"${mcpName}","gallery":true,"url":"${transportURL}"}'
      }
      {
        description: documentationDescription != '' ? documentationDescription : '${mcpName} MCP documentation'
        title: documentationTitle != '' ? documentationTitle : '${mcpName} MCP documentation'
        url: documentationURL
      }
    ] : [
      {
        description: 'Install VS Code'
        title: 'Install VS Code'
        url: 'vscode:mcp/install?{"name":"${mcpName}","gallery":true,"url":"${transportURL}"}'
      }
    ]
    contacts: []
    customProperties: {}
    summary: mcpDescription
    description: mcpDescription
  }
}

// Add API Version resource
resource apiVersion 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-03-01' = {
  parent: apiCenterAPI
  name: '1-0-0'
  properties: {
    title: '1-0-0'
    lifecycleStage: 'production'
  }
}

// Add API Definition resource
resource apiDefinition 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-03-01' = {
  parent: apiVersion
  name: 'default'
  properties: {
    description: 'default'
    title: 'default'
  }
}

// Add API Deployment resource
resource apiDeployment 'Microsoft.ApiCenter/services/workspaces/apis/deployments@2024-03-01' = {
  parent: apiCenterAPI
  name: 'mcpdeployment'
  properties: {
    description: 'mcpdeployment'
    title: 'mcpdeployment'
    environmentId: '/workspaces/default/environments/${apiEnvironment.name}'
    definitionId: '/workspaces/default/apis/${mcpName}/versions/${apiVersion.name}/definitions/${apiDefinition.name}'
    state: 'active'
    server: {
      runtimeUri: [
        transportURL
      ]
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

// Output environment details
output apiCenterService string = apiCenterService.name
output registeredMcpServer string = mcpName
output mcpServerDescription string = mcpDescription
