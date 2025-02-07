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
param openAIAPIVersion string = '2024-02-01'
param policyXml string

param embeddingsDeploymentName string = 'text-embedding-ada-002'
param embeddingsModelName string = 'text-embedding-ada-002'
param embeddingsModelVersion string = '2'

param redisCacheName string = 'rediscache'
param redisCacheSKU string = 'Balanced_B0'
param redisCachePort int = 10000

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'
var openAISubscriptionName = 'openai-subscription'
var openAISubscriptionDescription = 'OpenAI Subscription'
var openAIAPIName = 'openai'

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

// 3. Redis Cache
// 2/4/25: 2024-10-01 is not yet available in all regions. 2024-09-01-preview is more widely available.

// https://learn.microsoft.com/azure/templates/microsoft.cache/redisenterprise
resource redisEnterprise 'Microsoft.Cache/redisEnterprise@2024-09-01-preview' = {
  name: '${redisCacheName}-${resourceSuffix}'
  location: resourceGroup().location
  sku: {
    name: redisCacheSKU
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.cache/redisenterprise/databases
resource redisCache 'Microsoft.Cache/redisEnterprise/databases@2024-09-01-preview' = {
  name: 'default'
  parent: redisEnterprise
  properties: {
    evictionPolicy: 'NoEviction'
    clusteringPolicy: 'EnterpriseCluster'
    modules: [
      {
        name: 'RediSearch'
      }
    ]
    port: redisCachePort
  }
}

// 4. API Management
module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
  }
}

// 5. Cognitive Services
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
    lawId: lawId
  }
}

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: '${openAIConfig[0].name}-${resourceSuffix}'
}

resource embeddingsDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: embeddingsDeploymentName
  parent: cognitiveService
  properties: {
    model: {
      format: (length(openAIModule.outputs.extendedOpenAIConfig) > 0) ? 'OpenAI': ''
      name: embeddingsModelName
      version: embeddingsModelVersion
    }
  }
  sku: {
      name: 'Standard'
      capacity: 20
  }
  dependsOn: [
    cognitiveService
  ]
}

// 6. APIM OpenAI API
module openAIAPIModule '../../modules/apim/v1/openai-api.bicep' = {
  name: 'openAIAPIModule'
  params: {
    policyXml: policyXml
    openAIConfig: openAIModule.outputs.extendedOpenAIConfig
    openAIAPIVersion: openAIAPIVersion
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
  }
}

// 7. Create New APIM Subscriptions

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
    openAIAPIModule
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

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/caches
resource apimCache 'Microsoft.ApiManagement/service/caches@2024-06-01-preview' = {
  name: 'Default'
  parent: apim
  properties: {
    connectionString: '${redisEnterprise.properties.hostName}:${redisCachePort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
    useFromLocation: 'Default'
    description: redisEnterprise.properties.hostName
  }
}

resource backendEmbeddings 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'embeddings-backend' // this name is hard coded in the policy.xml file
  parent: apim
  properties: {
    description: 'Embeddings Backend'
    url: '${openAIModule.outputs.extendedOpenAIConfig[0].endpoint}openai/deployments/${embeddingsDeploymentName}/embeddings'
    protocol: 'http'
  }
}

// ------------------
//    MARK: OUTPUTS
// ------------------

output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName
output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimServiceName string = apimModule.outputs.name
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscription1Key string = apimSubscriptions[0].listSecrets().primaryKey
#disable-next-line outputs-should-not-contain-secrets
output apimSubscription2Key string = apimSubscriptions[1].listSecrets().primaryKey
#disable-next-line outputs-should-not-contain-secrets
output apimSubscription3Key string = apimSubscriptions[2].listSecrets().primaryKey

output redisCacheHost string = redisEnterprise.properties.hostName
#disable-next-line outputs-should-not-contain-secrets
output redisCacheKey string = redisCache.listKeys().primaryKey
output redisCachePort int = redisCachePort
