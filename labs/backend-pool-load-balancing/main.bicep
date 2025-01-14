// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string
param openAIAPIVersion string = '2024-02-01'
param openAIModelCapacity int = 8

// ------------------
//    VARIABLES
// ------------------

var updatedPolicyXml = loadTextContent('policy-updated.xml')

// ------------------
//    RESOURCES
// ------------------

// 1. API Management Instance
module apimModule '../../modules/apim/v2/apim.bicep' = {
  name: 'apimModule'
}

// 2. Cognitive Services
module openAIModule '../../modules/cognitive-services/v2/openai.bicep' = {
  name: 'openAIModule'
  params: {
    openAIConfig: openAIConfig
    openAIDeploymentName: openAIDeploymentName
    openAIModelName: openAIModelName
    openAIModelVersion: openAIModelVersion
    openAIModelCapacity: openAIModelCapacity
    apimPrincipalId: apimModule.outputs.principalId
  }
}

// 3. API Management APIs
module apimOpenAIAPIModule '../../modules/apim-openai-api/v1/openai-api.bicep' = {
  name: 'apimOpenAIAPIModule'
  params: {
    openAIConfig: openAIModule.outputs.extendedOpenAIConfig
    openAIAPIVersion: openAIAPIVersion
    policyXml: updatedPolicyXml
  }
}

// ------------------
//    OUTPUTS
// ------------------

output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = apimOpenAIAPIModule.outputs.subscriptionPrimaryKey
