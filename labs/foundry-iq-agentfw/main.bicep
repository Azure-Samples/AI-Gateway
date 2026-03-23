// ------------------
//    PARAMETERS
// ------------------

@description('Configuration array for AI Services')
param aiServicesConfig array = []

@description('Configuration array for model deployments')
param modelsConfig array = []

@description('SKU for the API Management instance')
param apimSku string = 'Basicv2'

@description('Configuration array for APIM subscriptions')
param apimSubscriptionsConfig array = []

@description('Type of inference API')
param inferenceAPIType string = 'AzureOpenAI'

@description('Path for the inference API')
param inferenceAPIPath string = 'inference'

@description('Name of the AI Foundry project')
param foundryProjectName string = 'default'

@description('AI Search service location')
param searchServiceLocation string = resourceGroup().location

@description('AI Search service SKU')
param searchServiceSku string = 'standard'

@description('API Path for AI Search API in APIM')
param aiSearchAPIPath string = 'ai-search'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var searchServiceName = 'search-${resourceSuffix}'
var azureRoles = loadJsonContent('../../modules/azure-roles.json')

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

// 4. AI Foundry (Cognitive Services + Project)
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
  name: 'foundryModule'
  params: {
    aiServicesConfig: aiServicesConfig
    modelsConfig: modelsConfig
    apimPrincipalId: apimModule.outputs.principalId
    foundryProjectName: foundryProjectName
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 5. APIM Inference API (for OpenAI model traffic through APIM)
module inferenceAPIModule '../../modules/apim/v3/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}

// 6. Azure AI Search
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: searchServiceLocation
  sku: {
    name: searchServiceSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    semanticSearch: 'standard'
    replicaCount: 1
    partitionCount: 1
  }
}

// 7. RBAC: Grant APIM managed identity "Search Index Data Contributor" on Azure AI Search
var searchIndexDataContributorRoleId = resourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7')
resource roleAssignmentApimSearchIndex 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchService.name, searchIndexDataContributorRoleId, 'apim')
  properties: {
    roleDefinitionId: searchIndexDataContributorRoleId
    principalId: apimModule.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// 8. RBAC: Grant APIM managed identity "Search Service Contributor" on Azure AI Search
var searchServiceContributorRoleId = resourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
resource roleAssignmentApimSearchService 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchService.name, searchServiceContributorRoleId, 'apim')
  properties: {
    roleDefinitionId: searchServiceContributorRoleId
    principalId: apimModule.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// 9. RBAC: Grant AI Foundry project managed identity access to Azure AI Search
var cognitiveServicesUserRoleId = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesUser)
resource roleAssignmentFoundrySearchIndex 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchService.name, searchIndexDataContributorRoleId, 'foundry')
  properties: {
    roleDefinitionId: searchIndexDataContributorRoleId
    principalId: foundryModule.outputs.extendedAIServicesConfig[0].cognitiveService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// 10. RBAC: Grant deployer "Search Service Contributor" + "Search Index Data Contributor" on Azure AI Search
resource roleAssignmentDeployerSearchService 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchService.name, searchServiceContributorRoleId, 'deployer')
  properties: {
    roleDefinitionId: searchServiceContributorRoleId
    principalId: deployer().objectId
  }
}

resource roleAssignmentDeployerSearchIndex 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchService.name, searchIndexDataContributorRoleId, 'deployer')
  properties: {
    roleDefinitionId: searchIndexDataContributorRoleId
    principalId: deployer().objectId
  }
}

// 11. RBAC: Grant AI Search managed identity "Cognitive Services OpenAI User" on AI Services (for vectorizer)
resource roleAssignmentSearchOpenAI 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(subscription().id, resourceGroup().id, 'search-openai-user', cognitiveServicesUserRoleId)
  properties: {
    roleDefinitionId: cognitiveServicesUserRoleId
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// 12. PassThrough API in APIM to AI Search backend
module aiSearchAPIModule '../../modules/apim/v3/ai-search-api.bicep' = {
  name: 'aiSearchAPIModule'
  params: {
    apimLoggerId: apimModule.outputs.loggerId
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
    searchServiceEndpoint: 'https://${searchService.name}.search.windows.net'
    searchServiceName: searchService.name
    searchAPIPath: aiSearchAPIPath
  }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output applicationInsightsName string = appInsightsModule.outputs.name
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output foundryProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].foundryProjectEndpoint
output searchServiceEndpoint string = 'https://${searchService.name}.search.windows.net'
output searchServiceName string = searchService.name
output aiServicesEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].endpoint
output aiServicesName string = foundryModule.outputs.extendedAIServicesConfig[0].cognitiveServiceName
output searchAPIPath string = aiSearchAPIModule.outputs.searchAPIPath
