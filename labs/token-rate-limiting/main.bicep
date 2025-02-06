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
param openAIAPIVersion string

// ------------------
//    VARIABLES
// ------------------

// Account for all placeholders in the polixy.xml file.
var policyXml = loadTextContent('policy.xml')
var updatedPolicyXml = replace(policyXml, '{backend-id}', (length(openAIConfig) > 1) ? 'openai-backend-pool' : openAIConfig[0].name)

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

// 3. APIM OpenAI API
module openAIAPIModule '../../modules/apim/v1/openai-api.bicep' = {
  name: 'openAIAPIModule'
  params: {
    policyXml: updatedPolicyXml
    openAIConfig: openAIModule.outputs.extendedOpenAIConfig
    openAIAPIVersion: openAIAPIVersion
  }
}

// ------------------
//    MARK: OUTPUTS
// ------------------
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = openAIAPIModule.outputs.subscriptionPrimaryKey
