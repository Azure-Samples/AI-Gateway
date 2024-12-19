// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

// Required parameters
param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string
param openAIAPIVersion string
// Optional parameters
param apimResourceName string = 'apim'
param apimPublisherEmail string = 'noreply@microsoft.com'
param apimPublisherName string = 'Microsoft'
param openAIAPIName string = 'openai'
param openAIAPIPath string = 'openai'
param openAIAPIDisplayName string = 'OpenAI'
param openAIAPIDescription string = 'Azure OpenAI API inferencing API'
param openAISubscriptionName string = 'openai-subscription'
param openAISubscriptionDescription string = 'OpenAI Subscription'
param openAIBackendPoolName string = 'openai-backend-pool'
param openAIBackendPoolDescription string = 'Load balancer for multiple OpenAI endpoints'
param logAnalyticsName string = 'workspace'
param applicationInsightsName string = 'insights'
param apimLoggerName string = 'apim-logger'
param apimLoggerDescription string  = 'APIM Logger for OpenAI API'
param workbookName string = 'OpenAIUsageAnalysis'
param workbookDisplayName string = 'OpenAI Usage Analysis'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apimManagementName = '${apimResourceName}-${resourceSuffix}'
var updatedPolicyXml = loadTextContent('policy-updated.xml')
var openAIAPISpecURL = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/${openAIAPIVersion}/inference.json'
var azureRoles = loadJsonContent('../../modules/azure-roles.json')
var cognitiveServicesOpenAIUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
  params: {
    logAnalyticsName: logAnalyticsName
  }
}

var lawId = lawModule.outputs.id

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    applicationInsightsName: applicationInsightsName
    workbookName: workbookName
    workbookDisplayName: workbookDisplayName
    workbookJson: loadTextContent('openai-usage-analysis-workbook.json')
    lawId: lawId
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
    apiManagementName: apimManagementName
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    policyXml: updatedPolicyXml
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
    apimLoggerName: apimLoggerName
    apimLoggerDescription: apimLoggerDescription
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
  }
}

var apimPrincipalId = apimModule.outputs.principalId

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
output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = apimModule.outputs.subscriptionPrimaryKey
