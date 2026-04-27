// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference' // Path to the inference API in the APIM service
param foundryProjectName string = 'default'

param embeddingsModel string

param redisCacheName string = 'rediscache'
param redisCacheSKU string = 'Balanced_B0'
param redisCachePort int = 10000

// ------------------
//    VARIABLES
// ------------------
var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'


// ------------------
//    RESOURCES
// ------------------

// 1. Redis
// https://learn.microsoft.com/azure/templates/microsoft.cache/redisenterprise
resource redisEnterprise 'Microsoft.Cache/redisEnterprise@2025-05-01-preview' = {
  name: '${redisCacheName}-${resourceSuffix}'
  location: resourceGroup().location
  sku: {
    name: redisCacheSKU
  }
}
// https://learn.microsoft.com/azure/templates/microsoft.cache/redisenterprise/databases
resource redisCache 'Microsoft.Cache/redisEnterprise/databases@2025-05-01-preview' = {
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
module apimModule '../../modules/apim/v2/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
  }
}

// 3. APIM Cache
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = if (length(apimModule.outputs.id) > 0) {
  name: apiManagementName
}
// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/caches
resource apimCache 'Microsoft.ApiManagement/service/caches@2024-06-01-preview' = {
  name: 'Default'
  parent: apimService
  properties: {
    connectionString: '${redisEnterprise.properties.hostName}:${redisCachePort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
    useFromLocation: 'Default'
    description: redisEnterprise.properties.hostName
  }
}

// 4. AI Foundry
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
    name: 'foundryModule'
    params: {
      aiServicesConfig: aiServicesConfig
      modelsConfig: modelsConfig
      apimPrincipalId: apimModule.outputs.principalId
      foundryProjectName: foundryProjectName
    }
  }

// 5. Embeddings Backend
resource backendEmbeddings 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'embeddings-backend' // this name is hard coded in the policy.xml file
  parent: apimService
  properties: {
    description: 'Embeddings Backend'
    url: '${foundryModule.outputs.extendedAIServicesConfig[0].endpoint}openai/deployments/${embeddingsModel}/embeddings'
    protocol: 'http'
  }
}

// 6. APIM Inference API
module inferenceAPIModule '../../modules/apim/v2/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
  dependsOn: [
    backendEmbeddings
  ]
}

// ------------------
//    OUTPUTS
// ------------------

output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions

output redisCacheHost string = redisEnterprise.properties.hostName
#disable-next-line outputs-should-not-contain-secrets
output redisCacheKey string = redisCache.listKeys().primaryKey
output redisCachePort int = redisCachePort
