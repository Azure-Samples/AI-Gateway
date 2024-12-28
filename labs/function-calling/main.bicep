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
param apimResourceName string = 'string'
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

@description('The name of the function app')
param functionAppName string

@description('Location for the function app')
param functionAppLocation string = resourceGroup().location

@description('The name of the function with the http trigger')
param functionName string = 'WeatherHttpTrigger'

@description('The name of the storage account')
param storageAccountName string

@description('Location for the storage account')
param storageAccountLocation string = resourceGroup().location

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('The name of the APIM API for Function API')
param functionAPIName string = 'weather'

@description('The relative path of the APIM API for Function API')
param functionAPIPath string = 'weather'

@description('The display name of the APIM API for Function API')
param functionAPIDisplayName string = 'WeatherAPI'

@description('The description of the APIM API for Function API')
param functionAPIDescription string = 'Weather API'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = '${apimResourceName}-${resourceSuffix}'
var updatedPolicyXml = loadTextContent('policy-updated.xml')
var azureRoles = loadJsonContent('../../modules/azure-roles.json')
var openAIAPISpecURL = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/${openAIAPIVersion}/inference.json'
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
    apiManagementName: apiManagementName
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

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${storageAccountName}${resourceSuffix}'
  location: storageAccountLocation
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${functionAppName}-asp-${resourceSuffix}'
  location: functionAppLocation
  kind: 'linux'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${functionAppName}-${resourceSuffix}'
  location: functionAppLocation
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      pythonVersion: '3.11'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
      ]
      linuxFxVersion: 'Python|3.11'
    }
    httpsOnly: true
  }
}

// We presume the APIM resource has been created as part of this bicep flow.
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
}

resource functionApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: functionAPIName
  parent: apim
  properties: {
    apiType: 'http'
    description: functionAPIDescription
    displayName: functionAPIDisplayName
    format: 'openapi+json'
    path: functionAPIPath
    serviceUrl: 'https://${functionApp.properties.defaultHostName}/api/weather'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: loadTextContent('weather.json')
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
output functionAppResourceName string = functionApp.name
