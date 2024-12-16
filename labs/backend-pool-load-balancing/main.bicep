// ------------------
//    PARAMETERS
// ------------------

@description('List of OpenAI resources to create. Add pairs of name and location.')
param openAIConfig array = []

@description('Deployment Name')
param openAIDeploymentName string

@description('Azure OpenAI Sku')
@allowed([
  'S0'
])
param openAISku string = 'S0'

@description('Model Name')
param openAIModelName string

@description('Model Version')
param openAIModelVersion string

@description('Model Capacity')
param openAIModelCapacity int = 20

@description('The name of the API Management resource')
param apimResourceName string

@description('Location for the APIM resource')
param apimResourceLocation string = resourceGroup().location

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param apimSku string = 'Consumption'

@description('The email address of the owner of the service')
param apimPublisherEmail string = 'noreply@microsoft.com'

@description('The name of the owner of the service')
param apimPublisherName string = 'Microsoft'

@description('The name of the APIM API for OpenAI API')
param openAIAPIName string = 'openai'

@description('The relative path of the APIM API for OpenAI API')
param openAIAPIPath string = 'openai'

@description('The display name of the APIM API for OpenAI API')
param openAIAPIDisplayName string = 'OpenAI'

@description('The description of the APIM API for OpenAI API')
param openAIAPIDescription string = 'Azure OpenAI API inferencing API'

@description('Full URL for the OpenAI API spec')
param openAIAPISpecURL string = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json'

@description('The name of the APIM Subscription for OpenAI API')
param openAISubscriptionName string = 'openai-subscription'

@description('The description of the APIM Subscription for OpenAI API')
param openAISubscriptionDescription string = 'OpenAI Subscription'

@description('The name of the OpenAI backend pool')
param openAIBackendPoolName string = 'openai-backend-pool'

@description('The description of the OpenAI backend pool')
param openAIBackendPoolDescription string = 'Load balancer for multiple OpenAI endpoints'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

// ------------------
//    RESOURCES
// ------------------

/* ORDER OF CREATION

  1. Cognitive Services
  2. API Management
  3. RBAC Assignment

 */

// 1. Cognitive Services
module openAIModule '../../modules/cognitive-services/v1/openai.bicep' = {
  name: 'openAIModule'
  params: {
    openAIConfig: openAIConfig
    openAIDeploymentName: openAIDeploymentName
    openAISku: openAISku
    openAIModelName: openAIModelName
    openAIModelVersion: openAIModelVersion
    openAIModelCapacity: openAIModelCapacity
  }
}

var extendedOpenAIConfig = openAIModule.outputs.extendedOpenAIConfig

// 2. API Management
var apimManagementName = '${apimResourceName}-${resourceSuffix}'

module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    apiManagementName: apimManagementName
    location: apimResourceLocation
    apimSku: apimSku
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    policyXml: loadTextContent('policy-updated.xml')
    openAIConfig: extendedOpenAIConfig
    openAIAPIDescription:openAIAPIDescription
    openAIAPIDisplayName: openAIAPIDisplayName
    openAIAPIName: openAIAPIName
    openAIAPIPath: openAIAPIPath
    openAIAPISpecURL: openAIAPISpecURL
    openAIBackendPoolDescription: openAIBackendPoolDescription
    openAIBackendPoolName: openAIBackendPoolName
    openAISubscriptionDescription: openAISubscriptionDescription
    openAISubscriptionName: openAISubscriptionName
  }
}

var apimPrincipalId = apimModule.outputs.principalId

// 3. RBAC Assignment
var roleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(length(openAIConfig) > 0) {
  #disable-next-line use-stable-resource-identifiers
  scope: resourceGroup()
  name: guid(subscription().id, resourceGroup().id, openAIConfig[0].name, roleDefinitionID)
  properties: {
    roleDefinitionId: roleDefinitionID
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
