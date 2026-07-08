// ------------------
//    PARAMETERS
// ------------------

@description('Configuration array for AI Services. Each item needs name and location.')
param aiServicesConfig array = []

@description('Configuration array for model deployments.')
param modelsConfig array = []

@description('SKU for the API Management instance')
param apimSku string = 'Basicv2'

@description('Configuration array for APIM subscriptions')
param apimSubscriptionsConfig array = []

@description('Path for the inference API exposed in APIM')
param inferenceAPIPath string = 'inference'

@description('Type of inference API')
param inferenceAPIType string = 'AzureAI'

@description('Name of the AI Foundry project')
param foundryProjectName string = 'default'

@description('Index of the AI Services config entry that hosts the Foundry hosted agents (default: second entry).')
param foundryAgentAiServiceIndex int = 1

@description('Microsoft Entra object IDs to assign Foundry User (Azure AI User) across all Foundry resources in this deployment.')
param foundryUserObjectIds array = []

@description('Enable APIM proxy API for a deployed Hosted Agent Responses endpoint.')
param enableHostedAgentResponsesApi bool = false

@description('Hosted Agent ID to proxy via APIM (required when enableHostedAgentResponsesApi=true).')
param hostedAgentId string = ''

@description('APIM path for hosted agent responses API.')
param hostedAgentResponsesApiPath string = 'hosted-agent-responses'

@description('Hosted Agent Responses API version appended by APIM policy.')
param hostedAgentResponsesApiVersion string = '2025-05-15-preview'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'
var azureAIUserRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d')

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

// 4. AI Foundry with model deployments (for example, gpt-5-mini)
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

// Foundry accounts created by the module, referenced here for RBAC assignments.
resource aiFoundryAccounts 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = [for config in aiServicesConfig: {
  name: '${config.name}-${resourceSuffix}'
  dependsOn: [foundryModule]
}]

// 5. APIM Inference API pointing to Foundry/AI Services
module inferenceAPIModule '../../modules/apim/v3/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
    aiServicesConfig: [foundryModule.outputs.extendedAIServicesConfig[0]]
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}

// 6. Container Registry (for hosted agent images)
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'acr${resourceSuffix}'
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// Assign Foundry User role for all provided users on the model-hosting Foundry resource.
resource modelFoundryUserRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in foundryUserObjectIds: {
  name: guid(resourceGroup().id, aiFoundryAccounts[0].name, principalId, azureAIUserRoleDefinitionId)
  scope: aiFoundryAccounts[0]
  properties: {
    roleDefinitionId: azureAIUserRoleDefinitionId
    principalId: principalId
    principalType: 'User'
  }
}]

// Assign Foundry User role for all provided users on the hosted-agent Foundry resource.
resource agentFoundryUserRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in foundryUserObjectIds: {
  name: guid(resourceGroup().id, aiFoundryAccounts[foundryAgentAiServiceIndex].name, principalId, azureAIUserRoleDefinitionId)
  scope: aiFoundryAccounts[foundryAgentAiServiceIndex]
  properties: {
    roleDefinitionId: azureAIUserRoleDefinitionId
    principalId: principalId
    principalType: 'User'
  }
}]

// Repository-level ACR roles (ABAC-enabled roles)
var acrRepositoryReaderRoleId = resourceId('Microsoft.Authorization/roleDefinitions', 'b93aa761-3e63-49ed-ac28-beffa264f7ac')
var acrRepositoryWriterRoleId = resourceId('Microsoft.Authorization/roleDefinitions', '2a1e307c-b015-4ebd-883e-5b7698a07328')
var acrRepositoryCatalogListerRoleId = resourceId('Microsoft.Authorization/roleDefinitions', 'bfdb9389-c9a5-478a-bb2f-ba9ca092c3c7')
var acrPullRoleId = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var foundryAgentAccountName = '${aiServicesConfig[foundryAgentAiServiceIndex].name}-${resourceSuffix}'

resource foundryAgentAcrRepositoryReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, foundryAgentAccountName, acrRepositoryReaderRoleId)
  scope: containerRegistry
  properties: {
    roleDefinitionId: acrRepositoryReaderRoleId
    principalId: foundryModule.outputs.extendedAIServicesConfig[foundryAgentAiServiceIndex].principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign AcrPull to Foundry project for container image pulls
resource foundryAgentAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, foundryAgentAccountName, acrPullRoleId)
  scope: containerRegistry
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: foundryModule.outputs.extendedAIServicesConfig[foundryAgentAiServiceIndex].principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployerAcrRepositoryWriterRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deployer().objectId, containerRegistry.id, acrRepositoryWriterRoleId)
  scope: containerRegistry
  properties: {
    roleDefinitionId: acrRepositoryWriterRoleId
    principalId: deployer().objectId
  }
}

resource deployerAcrRepositoryCatalogListerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deployer().objectId, containerRegistry.id, acrRepositoryCatalogListerRoleId)
  scope: containerRegistry
  properties: {
    roleDefinitionId: acrRepositoryCatalogListerRoleId
    principalId: deployer().objectId
  }
}

// Existing APIM service reference for custom API resources.
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    apimModule
  ]
}

// Proxy Hosted Agent Responses API through APIM once a hosted agent is deployed.
resource hostedAgentResponsesApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = if(enableHostedAgentResponsesApi && !empty(hostedAgentId)) {
  name: 'hosted-agent-responses-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'Proxy for Azure AI Foundry Hosted Agent Responses API'
    displayName: 'Hosted Agent Responses API'
    path: hostedAgentResponsesApiPath
    protocols: [
      'https'
    ]
    serviceUrl: '${foundryModule.outputs.extendedAIServicesConfig[foundryAgentAiServiceIndex].foundryProjectEndpoint}/agents/${split(hostedAgentId, ':')[0]}'
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
  }
}

resource hostedAgentResponsesOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = if(enableHostedAgentResponsesApi && !empty(hostedAgentId)) {
  name: 'create-response'
  parent: hostedAgentResponsesApi
  properties: {
    displayName: 'Create Hosted Agent Response'
    method: 'POST'
    urlTemplate: '/endpoint/protocols/openai/responses'
    templateParameters: []
    responses: [
      {
        statusCode: 200
        description: 'Successful response'
      }
    ]
  }
}

resource hostedAgentResponsesApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = if(enableHostedAgentResponsesApi && !empty(hostedAgentId)) {
  name: 'policy'
  parent: hostedAgentResponsesApi
  properties: {
    format: 'rawxml'
    value: loadTextContent('hosted-agent-policy.xml')
  }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimGatewayUrl string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output aiGatewayUrl string = '${apimModule.outputs.gatewayUrl}/${inferenceAPIPath}'
output foundryProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].foundryProjectEndpoint
output foundryAiServicesEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].endpoint
output foundryAgentProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[foundryAgentAiServiceIndex].foundryProjectEndpoint
output foundryAgentAiServicesEndpoint string = foundryModule.outputs.extendedAIServicesConfig[foundryAgentAiServiceIndex].endpoint
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output hostedAgentResponsesApimPath string = enableHostedAgentResponsesApi && !empty(hostedAgentId) ? '${apimModule.outputs.gatewayUrl}/${hostedAgentResponsesApiPath}/responses' : ''
