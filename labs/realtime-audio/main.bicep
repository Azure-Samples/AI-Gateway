// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apimSku string
param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string
param openAIModelSKU string
param openAIModelCapacity int

// ------------------
//    VARIABLES
// ------------------

// Account for all placeholders in the polixy.xml file.
var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var policyXml = loadTextContent('policy.xml')
var apiManagementName = 'apim-${resourceSuffix}'

// ------------------
//    RESOURCES
// ------------------

// 1. API Management
module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
  }
}

// 2. Cognitive Services
module openAIModule '../../modules/cognitive-services/v1/openai.bicep' = {
  name: 'openAIModule'
  params: {
    openAIConfig: openAIConfig
    openAIDeploymentName: openAIDeploymentName
    openAIModelName: openAIModelName
    openAIModelVersion: openAIModelVersion
    openAIModelSKU: openAIModelSKU
    openAIModelCapacity: openAIModelCapacity
    apimPrincipalId: apimModule.outputs.principalId
  }
}

// 3. APIM OpenAI-RT Websocket API
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'realtime-audio'
  parent: apimService
  properties: {
    apiType: 'websocket'
    description: 'Inference API for Azure OpenAI Realtime'
    displayName: 'InferenceAPI'
    path: 'rt-audio/openai/realtime'
    serviceUrl: concat(replace(openAIModule.outputs.extendedOpenAIConfig[0].endpoint, 'https:', 'wss:'),'openai/realtime')
    type: 'websocket'
    protocols: [
      'wss'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
  }
}

resource rtOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  name: 'onHandshake'
  parent: api
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource rtPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: rtOperation
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}


resource apimSubscriptionResource 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'realtime-client-sub'
  parent: apimService
  properties: {
    allowTracing: true
    displayName: 'realtime-client'
    scope: '/apis/${api.name}'
    state: 'active'
  }
}


// ------------------
//    MARK: OUTPUTS
// ------------------
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = apimSubscriptionResource.listSecrets().primaryKey
output openAIEndpoint string = openAIModule.outputs.extendedOpenAIConfig[0].endpoint
