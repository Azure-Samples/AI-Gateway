// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string
param openAIAPIVersion string

// ------------------
//    VARIABLES
// ------------------

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
