// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string
param openAIAPIVersion string = '2024-02-01'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'
var openAISubscriptionName = 'openai-subscription'
var openAISubscriptionDescription = 'OpenAI Subscription'
var openAIAPIName = 'openai'
var updatedPolicyXml = loadTextContent('policy-updated.xml')
var azureRoles = loadJsonContent('../../modules/azure-roles.json')
var cognitiveServicesOpenAIUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

var lawId = lawModule.outputs.id

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    workbookJson: loadTextContent('openai-usage-analysis-workbook.json')
    lawId: lawId
    customMetricsOptedInType: 'WithDimensions'
  }
}

var appInsightsId = appInsightsModule.outputs.id
var appInsightsInstrumentationKey = appInsightsModule.outputs.instrumentationKey

// 3. Cognitive Services
module openAIModule '../../modules/cognitive-services/v1/openai.bicep' = {
    name: 'openAIModule'
    params: {
      openAIConfig: openAIConfig
      openAIDeploymentName: openAIDeploymentName
      openAIModelName: openAIModelName
      openAIModelVersion: openAIModelVersion
      lawId: lawId
    }
  }

var extendedOpenAIConfig = openAIModule.outputs.extendedOpenAIConfig

// 4. API Management
module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    policyXml: updatedPolicyXml
    openAIConfig: extendedOpenAIConfig
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
    openAIAPIVersion: openAIAPIVersion
    openAISubscriptionName: openAISubscriptionName
    openAISubscriptionDescription: openAISubscriptionDescription
  }
}

var apimPrincipalId = apimModule.outputs.principalId

// We presume the APIM resource has been created as part of this bicep flow.
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    apimModule
  ]
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apim
  name: openAIAPIName
  dependsOn: [
    apim
  ]
}

// Ignore the subscription that gets created in the APIM module and create three new ones for this lab.
resource apimSubscriptions 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = [for i in range(1, 3): {
  name: '${openAISubscriptionName}${i}'
  parent: apim
  properties: {
    allowTracing: true
    displayName: '${openAISubscriptionDescription} ${i}'
    scope: '/apis/${api.id}'
    state: 'active'
  }
  dependsOn: [
    api
  ]
}]

// 5. RBAC Assignment
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

output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName
output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscription1Key string = apimSubscriptions[0].listSecrets().primaryKey
#disable-next-line outputs-should-not-contain-secrets
output apimSubscription2Key string = apimSubscriptions[1].listSecrets().primaryKey
#disable-next-line outputs-should-not-contain-secrets
output apimSubscription3Key string = apimSubscriptions[2].listSecrets().primaryKey
