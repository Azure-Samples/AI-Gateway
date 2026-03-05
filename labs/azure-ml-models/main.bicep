// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference'
param foundryProjectName string = 'default'
param amlEndpointName string = 'forecast-endpoint'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var amlWorkspaceName = 'aml-${resourceSuffix}'
var amlEndpointBaseUrl = 'https://${amlEndpointName}${resourceSuffix}.${resourceGroup().location}.inference.ml.azure.com'

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawModule.outputs.id
    customMetricsOptedInType: 'WithDimensions'
  }
}

// 3. API Management
module apimModule '../../modules/apim/v3/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 4. AI Foundry
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
  name: 'foundryModule'
  params: {
    aiServicesConfig: aiServicesConfig
    modelsConfig: modelsConfig
    apimPrincipalId: apimModule.outputs.principalId
    foundryProjectName: foundryProjectName
  }
}

// 5. APIM Inference API
module inferenceAPIModule '../../modules/apim/v3/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}

// 6. Storage Account (for Azure ML workspace)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${resourceSuffix}'
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowSharedKeyAccess: true
  }
  tags: {
    SecurityControl: 'ignore'
  }
}

// 7. Key Vault (for Azure ML workspace)
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${resourceSuffix}'
  location: resourceGroup().location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
  }
  tags: {
    SecurityControl: 'ignore'
  }
}

// 8. Container Registry (for Azure ML model images)
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'cr${resourceSuffix}'
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
  tags: {
    SecurityControl: 'ignore'
  }
}

// 9. Azure ML Workspace
resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: amlWorkspaceName
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: amlWorkspaceName
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    containerRegistry: containerRegistry.id
    applicationInsights: appInsightsModule.outputs.id
  }
  tags: {
    SecurityControl: 'ignore'
  }
}

// 10. Azure ML Online Endpoint (empty - deployment created via CLI in notebook)
resource mlEndpoint 'Microsoft.MachineLearningServices/workspaces/onlineEndpoints@2024-04-01' = {
  parent: mlWorkspace
  name: '${amlEndpointName}${resourceSuffix}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authMode: 'AADToken'
  }
}

// 11. Role Assignment - APIM managed identity gets AzureML Data Scientist role on ML workspace
resource apimMlRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: '11-${guid(amlWorkspaceName, resourceSuffix, 'f6c7c914-8db3-469d-8ca1-694a8f32e121')}'
  scope: mlWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f6c7c914-8db3-469d-8ca1-694a8f32e121')
    principalId: apimModule.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// 12. ML Prediction API in APIM
module mlPredictionAPIModule 'src/ml-prediction/api/api.bicep' = {
  name: 'mlPredictionAPIModule'
  params: {
    apimServiceName: apimModule.outputs.name
    amlEndpointUrl: amlEndpointBaseUrl
  }
  dependsOn: [
    inferenceAPIModule
    mlEndpoint
  ]
}

// 13. MCP Server wrapping the ML Prediction API
module mlMCPModule 'src/ml-prediction/mcp-server/mcp.bicep' = {
  name: 'mlMCPModule'
  params: {
    apimServiceName: apimModule.outputs.name
  }
  dependsOn: [
    mlPredictionAPIModule
  ]
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output foundryProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].foundryProjectEndpoint
output amlWorkspaceName string = mlWorkspace.name
output amlEndpointName string = mlEndpoint.name
output mcpEndpoint string = mlMCPModule.outputs.endpoint
