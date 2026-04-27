// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apicsku string = 'Free'
param location string = resourceGroup().location
param apicServiceName string


// ------------------
//    VARIABLES
// ------------------

// Load MCP configurations from JSON file
var mcpConfigs = json(loadTextContent('remote-mcp-servers.json')).mcps

// ------------------
//    RESOURCES
// ------------------

// Create API Center Service resource
resource apiCenterService 'Microsoft.ApiCenter/services@2024-06-01-preview' = {
  name: apicServiceName
  location: location
  sku: {
    name: apicsku
  }
}

// Use default workspace
resource apiCenterWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-06-01-preview' = {
  parent: apiCenterService
  name: 'default'
  properties: {
    title: 'Default workspace'
    description: 'Default workspace'
  }
}

// Add environment resources
resource apiEnvironment 'Microsoft.ApiCenter/services/workspaces/environments@2024-06-01-preview' = {
  parent: apiCenterWorkspace
  name: 'api'
  properties: {
    title: 'api'
    description: 'API default environment'
    kind: 'rest'
    server: {
      managementPortalUri: [
        'https://portal.azure.com/'
      ]
      type: 'other'
    }
  }
}

resource mcpEnvironment 'Microsoft.ApiCenter/services/workspaces/environments@2024-06-01-preview' = {
  parent: apiCenterWorkspace
  name: 'mcp'
  properties: {
    title: 'mcp'
    description: 'mcp default environment'
    kind: 'mcp'
    server: {
      managementPortalUri: [
        'https://portal.azure.com/'
      ]
      type: 'other'
    }
  }
}

// Add API resources using a loop
resource apiCenterAPI 'Microsoft.ApiCenter/services/workspaces/apis@2024-06-01-preview' = [for mcp in mcpConfigs: {
  parent: apiCenterWorkspace
  name: mcp.mcpName
  properties: {
    title: '${toUpper(substring(mcp.mcpName, 0, 1))}${substring(mcp.mcpName, 1)}'
    kind: 'mcp'
    lifecycleState: 'production'
    externalDocumentation: [
      {
        description: 'Install VS Code'
        title: 'Install VS Code'
        url: 'https://insiders.vscode.dev/redirect/mcp/install?name=${mcp.mcpName}&config={"type":"sse","url":"${mcp.InstallVSCodeURL}"}'
      }
      {
        description: '${mcp.mcpName} MCP documentation'
        title: '${mcp.mcpName} MCP documentation'
        url: mcp.DodumentationURL
      }
    ]
    contacts: []
    customProperties: {}
    summary: mcp.description
    description: mcp.description
  }
}]

// Add API Version resources using a loop
resource apiVersion 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-06-01-preview' = [for (mcp, i) in mcpConfigs: {
  parent: apiCenterAPI[i]
  name: '1-0-0'
  properties: {
    title: '1-0-0'
    lifecycleStage: 'production'
  }
}]

// Add API Definition resource
resource apiDefinition 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-06-01-preview' = [for (mcp, i) in mcpConfigs: {
  parent: apiVersion[i]
  name: 'default'
  properties: {
    description: 'default'
    title: 'default'
  }
}]

// Add API Deployment resource
resource apiDeployment 'Microsoft.ApiCenter/services/workspaces/apis/deployments@2024-06-01-preview' = [for (mcp, i) in mcpConfigs: {
  parent: apiCenterAPI[i]
  name: 'mcpdeployment'
  properties: {
    description: 'mcpdeployment'
    title: 'mcpdeployment'
    environmentId: '/workspaces/default/environments/${apiEnvironment.name}'
    definitionId: '/workspaces/default/apis/${mcp.mcpName}/versions/${apiVersion[i].name}/definitions/${apiDefinition[i].name}'
    state: 'active'
    server: {
      runtimeUri: [
        mcp.InstallVSCodeURL
      ]
    }
  }
}]

// ------------------
//    OUTPUTS
// ------------------

output id string = apiCenterService.id
output name string = apiCenterService.name

output apiEnvironmentName string = apiEnvironment.name
output mcpEnvironmentName string = mcpEnvironment.name
