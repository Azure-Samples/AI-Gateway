// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apimSku string
param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string
param openAIModelCapacity int
param openAIAPIVersion string

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

// Account for all placeholders in the polixy.xml file.
var policyXml = loadTextContent('policy.xml')
var updatedPolicyXml = replace(policyXml, '{backend-id}', (length(openAIConfig) > 1) ? 'openai-backend-pool' : openAIConfig[0].name)

// ------------------
//    RESOURCES
// ------------------

// 1. Redis Cache
resource redisEnterprise 'Microsoft.Cache/redisEnterprise@2024-09-01-preview' = {
  name: '${redisCacheName}-${resourceSuffix}'
  location: resourceGroup().location
  sku: {
    name: redisCacheSKU
  }
}

resource redisCache 'Microsoft.Cache/redisEnterprise/databases@2022-01-01' = {
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

// 2. API Management
module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
  }
}

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = if (length(apimModule.outputs.id) > 0) {
  name: apiManagementName
}

resource apimCache 'Microsoft.ApiManagement/service/caches@2021-12-01-preview' = {
  name: 'Default'
  parent: apimService
  properties: {
    connectionString: '${redisEnterprise.properties.hostName}:${redisCachePort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
    useFromLocation: 'Default'
    description: redisEnterprise.properties.hostName
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
    openAIModelCapacity: openAIModelCapacity
    apimPrincipalId: apimModule.outputs.principalId
  }
}
resource cognitiveService 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = if (length(openAIModule.outputs.extendedOpenAIConfig) > 0) {
  name: '${openAIConfig[0].name}-${resourceSuffix}'
}
resource embeddingsDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: embeddingsDeploymentName
  parent: cognitiveService
  properties: {
    model: {
      format: 'OpenAI'
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

// 3. APIM OpenAI API
resource backendEmbeddings 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'embeddings-backend' // this name is hard coded in the policy.xml file
  parent: apimService
  properties: {
    description: 'Embeddings Backend'
    url: '${openAIModule.outputs.extendedOpenAIConfig[0].endpoint}openai/deployments/${embeddingsDeploymentName}/embeddings'
    protocol: 'http'
  }
}
module openAIAPIModule '../../modules/apim/v1/openai-api.bicep' = {
  name: 'openAIAPIModule'
  params: {
    policyXml: updatedPolicyXml
    openAIConfig: openAIModule.outputs.extendedOpenAIConfig
    openAIAPIVersion: openAIAPIVersion
  }
  dependsOn: [
    backendEmbeddings
  ]
}

// ------------------
//    MARK: OUTPUTS
// ------------------
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = openAIAPIModule.outputs.subscriptionPrimaryKey

output redisCacheHost string = redisEnterprise.properties.hostName
#disable-next-line outputs-should-not-contain-secrets 
output redisCacheKey string = redisCache.listKeys().primaryKey
output redisCachePort int = redisCachePort
