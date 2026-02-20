// ------------------
//    PARAMETERS
// ------------------

@description('Configuration array for AI Services')
param aiServicesConfig array = []

@description('Configuration array for model deployments')
param modelsConfig array = []

@description('SKU for the API Management instance')
param apimSku string = 'Developer'

@description('Configuration array for APIM subscriptions')
param apimSubscriptionsConfig array = []

@description('Path for the inference API')
param inferenceAPIPath string = 'inference'

@description('Type of inference API')
param inferenceAPIType string = 'AzureAI'

@description('Name of the AI Foundry project')
param foundryProjectName string = 'default'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

// Model Gateway models array
var modelGatewayModels = [for model in modelsConfig: {
  name: model.name
  properties: {
    model: {
      name: model.name
      version: model.version
      format: model.publisher
    }
  }
}]

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
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 5. APIM Inference API
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

// 6. Reference the existing Cognitive Services account created by foundry module
// Calculate the name using the same pattern as the foundry module
// Reference the AI Foundry account
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: '${aiServicesConfig[1].name}-${resourceSuffix}'
  scope: resourceGroup()
}

// 7. Model Gateway Connection - Connect APIM as a model gateway to Foundry
resource modelGatewayConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  parent: aiFoundry
  name: 'ai-gateway'
  properties: {
    authType: 'ApiKey'
    category: 'ApiManagement'
    target: '${apimModule.outputs.gatewayUrl}/${inferenceAPIPath}/openai'
    isSharedToAll: true
    credentials: {
      key: apimModule.outputs.apimSubscriptions[0].key
    }
    metadata: {
      ApiType: 'Azure'
      inferenceAPIVersion: '2024-12-01-preview'
      //deploymentAPIVersion: '2024-12-01-preview'
      Location: aiServicesConfig[0].location
      deploymentInPath: 'true'
      models: string(modelGatewayModels)
    }
  }
  dependsOn: [
    inferenceAPIModule
  ]
}


/// TRYING TO REPLECATE THAT AI GATEWAY FROM PORTAL - NOT WORKING YET, NEED TO CHECK FURTHER
// resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
//   name: apimModule.outputs.name
//   scope: resourceGroup()
// }
// resource apimProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' existing = {
//   parent: apim
//   name: 'starter'
// }
// resource foundryAPIMLink 'Microsoft.Resources/links@2016-09-01' = {
//   name: 'foundry-to-apim-link'
//   scope: aiFoundry
//   properties: {
//     targetId: apimProduct.id
//   }
// }

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output AgentsfoundryProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[1].foundryProjectEndpoint
output AgentsfoundryAIServicesEndpoint string = foundryModule.outputs.extendedAIServicesConfig[1].endpoint
output aiGatewayUrl string = '${apimModule.outputs.gatewayUrl}/${inferenceAPIPath}'
output aiGatewayConnectionName string = modelGatewayConnection.name
