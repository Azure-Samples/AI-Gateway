// ------------------
//    PARAMETERS
// ------------------

@description('Configuration array for AI Services')
param aiServicesConfig array = []

@description('Configuration array for models')
param modelsConfig array = []

@description('The SKU for the API Management service')
param apimSku string

@description('Configuration array for APIM subscriptions')
param apimSubscriptionsConfig array = []

@description('The inference API type')
@allowed([
  'AzureOpenAI'
  'AzureAI'
  'OpenAI'
])
param inferenceAPIType string = 'AzureOpenAI'

@description('Path to the inference API in the APIM service')
param inferenceAPIPath string = 'inference'

@description('The name of the Foundry project')
param foundryProjectName string = 'default'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'

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
module apimModule '../../modules/apim/v2/apim.bicep' = {
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

// 5. APIM Inference API (initially without session affinity)
module inferenceAPIModule '../../modules/apim/v2/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIName: inferenceAPIType
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
    inferenceBackendPoolName: 'inference-backend-pool'
  }
}

// 6. Create backend pool WITH session affinity using script after deployment
// Note: Session affinity configuration will be applied via update script

// ------------------
//    OUTPUTS
// ------------------

output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output foundryInstances array = foundryModule.outputs.extendedAIServicesConfig
output apimServiceName string = apiManagementName
output resourceGroupName string = resourceGroup().name
