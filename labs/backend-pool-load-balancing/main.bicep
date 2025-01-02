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
var azureRoles = loadJsonContent('../../modules/azure-roles.json')
var cognitiveServicesOpenAIUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)

// ------------------
//    RESOURCES
// ------------------

// 1. Cognitive Services
module openAIModule '../../modules/cognitive-services/v1/openai.bicep' = {
  name: 'openAIModule'
  params: {
    openAIConfig: openAIConfig
    openAIDeploymentName: openAIDeploymentName
    openAIModelName: openAIModelName
    openAIModelVersion: openAIModelVersion
    openAIModelCapacity: openAIModelCapacity
  }
}

var extendedOpenAIConfig = openAIModule.outputs.extendedOpenAIConfig

// 2. API Management
module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    policyXml: updatedPolicyXml
    openAIConfig: extendedOpenAIConfig
    openAIAPIVersion: openAIAPIVersion
  }
}

var apimPrincipalId = apimModule.outputs.principalId

// 3. RBAC Assignment
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(length(openAIConfig) > 0) {
  scope: resourceGroup()
  name: guid(subscription().id, resourceGroup().id, openAIConfig[0].name, cognitiveServicesOpenAIUserRoleDefinitionID)
    properties: {
        roleDefinitionId: cognitiveServicesOpenAIUserRoleDefinitionID
        principalId: apimPrincipalId
        principalType: 'ServicePrincipal'
    }
}

// ------------------
//    OUTPUTS
// ------------------

output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = apimModule.outputs.subscriptionPrimaryKey
