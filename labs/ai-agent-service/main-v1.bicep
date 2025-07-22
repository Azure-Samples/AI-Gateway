// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apimSku string
param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIModelSKU string
param openAIDeploymentName string
param openAIModelCapacity int
param openAIAPIVersion string

@description('Configuration array for Inference Models')
param modelsConfig array = []

@description('The tags for the resources')
param tagValues object = {
}


@description('Name of the APIM Logger')
param apimLoggerName string = 'apim-logger'

// Creates Azure dependent resources for Azure AI studio

@description('Azure region of the deployment')
param location string = resourceGroup().location

param weatherAPIPath string = 'weatherservice'
param placeOrderAPIPath string = 'orderservice'
param productCatalogAPIPath string = 'catalogservice'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'

var openAIPolicyXML = loadTextContent('./v1/openai-policy.xml')
var updatedOpenAIPolicyXML = replace(openAIPolicyXML, '{backend-id}', (length(openAIConfig) > 1) ? 'openai-backend-pool' : openAIConfig[0].name)

var inferenceAPIPolicyXML = loadTextContent('./v1/inference-policy.xml')

var logSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens' , 'x-ratelimit-remaining-requests' ]
  body: { bytes: 8192 }
}

// ------------------
//    RESOURCES
// ------------------

resource bingSearch 'Microsoft.Bing/accounts@2020-06-10' = {
  name: 'bingsearch-${resourceSuffix}'
  location: 'global'
  kind: 'Bing.Grounding'
  sku: {
    name: 'G1'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${resourceSuffix}'
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'insights-${resourceSuffix}'
  location: location
  tags: tagValues
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    // BCP037: Not yet added to latest API: https://github.com/Azure/bicep-types-az/issues/2048
    #disable-next-line BCP037
    CustomMetricsOptedInType: 'WithDimensions'

  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementName
  location: location
  sku: {
    name: apimSku
    capacity: 1
  }
  properties: {
    publisherEmail: 'noreply@microsoft.com'
    publisherName: 'Microsoft'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Create a logger only if we have an App Insights ID and instrumentation key.
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: apimLoggerName
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: 'APIM Logger'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

resource placeOrderWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'ordersworkflow-${resourceSuffix}'
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        PlaceOrder: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                sku: {
                  type: 'string'
                }
                quantity: {
                  type: 'integer'
                }
              }
            }
          }
          description: 'Place an Order to the specified sku and quantity.'
        }
      }
      actions: {
        Condition: {
          actions: {
            UpdateStatusOk: {
              type: 'Response'
              kind: 'Http'
              inputs: {
                statusCode: 200
                body: {
                  status: '@concat(\'Order placed with id \', rand(1000,9000),\' for SKU \', triggerBody()?[\'sku\'], \' with \', triggerBody()?[\'quantity\'], \' items.\')'                  
                }
              }
              description: 'Return the status for the order.'
            }
          }
          runAfter: {}
          else: {
            actions: {
              UpdateStatusError: {
                type: 'Response'
                kind: 'Http'
                inputs: {
                  statusCode: 200
                  body: {
                    status: 'The order was not placed because the quantity exceeds the maximum limit of five items.'
                  }
                }
                description: 'Return the status for the order.'
              }
            }
          }
          expression: {
            and: [
              {
                lessOrEquals: [
                  '@triggerBody()?[\'quantity\']'
                  5
                ]
              }
            ]
          }
          type: 'If'
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {}
      }
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-04-01' = {
  name: 'storage${resourceSuffix}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    supportsHttpsTrafficOnly: true
  }
  tags: tagValues
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'vault-${resourceSuffix}'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableRbacAuthorization: true
    accessPolicies: []
  }
  tags: tagValues
}

resource openAIAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = [for config in openAIConfig: if(length(openAIConfig) > 0) {
  name: '${config.name}-${resourceSuffix}'
  location: config.location
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
    customSubDomainName: toLower('${config.name}-${resourceSuffix}')
  }
}]

resource aiServicesAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = if(length(modelsConfig) > 0) {
  name: 'aiservices-${resourceSuffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    customSubDomainName: toLower('aiservices-${resourceSuffix}')
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: false
  }
}

resource hub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: 'aihub-${resourceSuffix}'
  kind: 'Hub'
  location: location
  identity: {
    type: 'systemAssigned'
  }
  sku: {
    tier: 'Standard'
    name: 'standard'
  }
  properties: {
    description: 'Azure AI hub'
    friendlyName: 'AIHub'
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    applicationInsights: applicationInsights.id
    hbiWorkspace: false
  }
  tags: tagValues
}

resource project 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: 'project-${resourceSuffix}'
  kind: 'Project'
  location: location
  identity: {
    type: 'systemAssigned'
  }
  sku: {
    tier: 'Standard'
    name: 'standard'
  }
  properties: {
    description: 'Azure AI project'
    friendlyName: 'AIProject'
    hbiWorkspace: false
    hubResourceId: hub.id
  }
  tags: tagValues
}

@batchSize(1)
resource openAIDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: openAIDeploymentName
  parent: openAIAccount[i]
  properties: {
    model: {
      format: 'OpenAI'
      name: openAIModelName
      version: openAIModelVersion
    }
  }
  sku: {
      name: openAIModelSKU
      capacity: openAIModelCapacity
  }
}]

@batchSize(1)
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [for model in modelsConfig: if(length(modelsConfig) > 0) {
  name: model.name
  parent: aiServicesAccount
  sku: {
    name: model.sku
    capacity: model.capacity
  }
  properties: {
    model: {
      format: model.publisher
      name: model.name
      version: model.version
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}]

resource bingSearchConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01-preview' = {
  name: 'BingSearch'
  parent: hub
  properties: {
    category: 'ApiKey'
    authType: 'ApiKey'
    isSharedToAll: true
    target: 'https://api.bing.microsoft.com/'
    metadata: {
      ApiVersion: '2024-02-01'
      ApiType: 'azure'
      ResourceId: bingSearch.id
      location: 'global'
    }
    credentials: {
      key: bingSearch.listKeys().key1
    }
  }
}

resource openAIConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01-preview' = if(length(openAIConfig) > 0) {
  name: 'APIM_AzureOpenAI'
  parent: hub
  properties: {
    category: 'AzureOpenAI'
    authType: 'ApiKey'
    isSharedToAll: true
    target: apimService.properties.gatewayUrl
    metadata: {
      ApiVersion: openAIAPIVersion
      ApiType: 'azure'
      ResourceId: openAIAccount[0].id
    }
    credentials: {
      key: apimSubscription.listSecrets().primaryKey
    }
  }
}

resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01-preview' = if(length(modelsConfig) > 0) {
  name: 'APIM_AIServices'
  parent: hub
  properties: {
    category: 'AIServices'
    authType: 'ApiKey'
    target: apimService.properties.gatewayUrl
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServicesAccount.id
    }
    credentials: {
      key: apimSubscription.listSecrets().primaryKey
    }
  }
}

resource weatherAPIConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01-preview' = {
  name: 'WeatherAPI'
  parent: hub
  properties: {
    category: 'CustomKeys'
    authType: 'CustomKeys'
    target: '${apimService.properties.gatewayUrl}/${weatherAPIPath}'
    isSharedToAll: true
    credentials: {
      keys: {
        'api-key': apimSubscription.listSecrets().primaryKey
      }
    }
  }
}

resource placeOrderAPIConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01-preview' = {
  name: 'PlaceOrderAPI'
  parent: hub
  properties: {
    category: 'CustomKeys'
    authType: 'CustomKeys'
    target: '${apimService.properties.gatewayUrl}/${placeOrderAPIPath}'
    isSharedToAll: true
    credentials: {
      keys: {
        'api-key': apimSubscription.listSecrets().primaryKey
      }
    }
  }
}

resource productCatalogAPIConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01-preview' = {
  name: 'ProductCatalogAPI'
  parent: hub
  properties: {
    category: 'CustomKeys'
    authType: 'CustomKeys'
    target: '${apimService.properties.gatewayUrl}/${productCatalogAPIPath}'
    isSharedToAll: true
    credentials: {
      keys: {
        'api-key': apimSubscription.listSecrets().primaryKey
      }
    }
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings
resource openAIDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: '${openAIAccount[i].name}-diagnostics'
  scope: openAIAccount[i]
  properties: {
    workspaceId: logAnalytics.id
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}]

// https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings
resource aiServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(length(modelsConfig) > 0) {
  name: 'aiservices-diagnostics'
  scope: aiServicesAccount
  properties: {
    workspaceId: logAnalytics.id
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

var cognitiveServicesOpenAIUserRoleDefinitionID = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
resource openAIAccountRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: guid(subscription().id, resourceGroup().id, config.name, cognitiveServicesOpenAIUserRoleDefinitionID)
  scope: openAIAccount[i]
  properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleDefinitionID)
      principalId: apimService.identity.principalId
      principalType: 'ServicePrincipal'
  }
}]

var cognitiveServicesUserRoleDefinitionID = 'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services User
resource aiServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(length(modelsConfig) > 0) {
  name: guid(subscription().id, resourceGroup().id, cognitiveServicesUserRoleDefinitionID)
  scope: aiServicesAccount
  properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleDefinitionID)
      principalId: apimService.identity.principalId
      principalType: 'ServicePrincipal'
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource openAIAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = if(length(openAIConfig) > 0) {
  name: 'openai-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'OpenAI Inference API - ${openAIConnection.name}'
    displayName: 'OpenAI'
    format: 'openapi-link'
    path: 'openai'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/refs/heads/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/${(contains(openAIAPIVersion, 'preview')) ? 'preview' : 'stable'}/${openAIAPIVersion}/inference.json'
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource inferenceAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = if(length(modelsConfig) > 0) {
  name: 'inference-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'Inference API - ${aiServicesConnection.name}'
    displayName: 'InferenceAPI'
    format: 'openapi-link'
    path: 'models'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/refs/heads/main/specification/ai/data-plane/ModelInference/preview/2024-05-01-preview/openapi.json'
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource weatherAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'weather-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'City Weather API'
    displayName: 'City Weather API'
    format: 'openapi+json'
    path: weatherAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: loadTextContent('city-weather-openapi.json')
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource placeOrderAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'place-order-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'Place Order API'
    displayName: 'Place Order API'
    format: 'openapi+json'
    path: placeOrderAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: loadTextContent('place-order-openapi.json')
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource productCatalogAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'product-catalog-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'Product Catalog API'
    displayName: 'Product Catalog API'
    format: 'openapi+json'
    path: productCatalogAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: loadTextContent('product-catalog-openapi.json')
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource openAIAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = if(length(openAIConfig) > 0) {
  name: 'policy'
  parent: openAIAPI
  properties: {
    format: 'rawxml'
    value: updatedOpenAIPolicyXML
  }
  dependsOn: [
    backendOpenAI
  ]
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource inferenceAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = if(length(modelsConfig) > 0) {
  name: 'policy'
  parent: inferenceAPI
  properties: {
    format: 'rawxml'
    value: inferenceAPIPolicyXML
  }
  dependsOn: [
    backendInferenceAPI
  ]
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource weatherAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: weatherAPI
  properties: {
    format: 'rawxml'
    value: loadTextContent('city-weather-mock-policy.xml')
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource placeOrderAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: placeOrderAPI
  properties: {
    format: 'rawxml'
    value: loadTextContent('place-order-policy.xml')
  }
  dependsOn: [
    backendPlaceOrderAPI
  ]
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource productCatalogAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: productCatalogAPI
  properties: {
    format: 'rawxml'
    value: loadTextContent('product-catalog-mock-policy.xml')
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' =  [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: config.name
  parent: apimService
  properties: {
    description: 'Backend for the OpenAI API'
    url: '${openAIAccount[i].properties.endpoint}openai'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 1
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT5M'
            statusCodeRanges: [
              {
                min: 429
                max: 429
              }
            ]
          }
          name: 'openAIBreakerRule'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
  }
}]

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendInferenceAPI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = if(length(modelsConfig) > 0) {
  name: 'inference-backend'
  parent: apimService
  properties: {
    description: 'Backend for the inference API'
    url: '${aiServicesAccount.properties.endpoints['Azure AI Model Inference API']}models'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 1
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT5M'
            statusCodeRanges: [
              {
                min: 429
                max: 429
              }
            ]
          }
          name: 'openAIBreakerRule'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendPlaceOrderAPI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'orderworflow-backend'
  parent: apimService
  properties: {
    description: 'Backend for the Place Order API'
    url: '${placeOrderWorkflow.listCallbackUrl().basePath}/triggers'
    protocol: 'http'
    credentials: {
      query: {
          sig: [ placeOrderWorkflow.listCallbackUrl().queries.sig ]
          'api-version': [ placeOrderWorkflow.listCallbackUrl().queries['api-version'] ]
          sp: [ placeOrderWorkflow.listCallbackUrl().queries.sp ]
          sv: [ placeOrderWorkflow.listCallbackUrl().queries.sv ]        
      }
    }    
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendPoolOpenAI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = { // = if(length(openAIConfig) > 1) {
  name: 'openai-backend-pool'
  parent: apimService
  // BCP035: protocol and url are not needed in the Pool type. This is an incorrect error.
  #disable-next-line BCP035
  properties: {
    description: 'OpenAI Backend Pool'
    type: 'Pool'
    pool: {
      services: [for (config, i) in openAIConfig: {
        id: '/backends/${backendOpenAI[i].name}'
        priority: config.?priority
        weight: config.?weight
      }]
    }
  }
}

resource OpenAPIAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if(length(openAIConfig) > 0) {
  name: 'applicationinsights'
  parent: openAIAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apiManagementName, apimLoggerName)
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

resource inferenceAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if(length(modelsConfig) > 0) {
  name: 'applicationinsights'
  parent: inferenceAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apiManagementName, apimLoggerName)
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

resource weatherAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: weatherAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apiManagementName, apimLoggerName)
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

resource placeOrderAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: placeOrderAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apiManagementName, apimLoggerName)
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

resource productCatalogAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: productCatalogAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apiManagementName, apimLoggerName)
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'ai-foundry-subscription'
  parent: apimService
  properties: {
    allowTracing: true
    displayName: 'AI Foundry Subscription'
    scope: '/apis'
    state: 'active'
  }
}



// ------------------
//    OUTPUTS
// ------------------
var projectEndoint = replace(replace(project.properties.discoveryUrl, 'https://', ''), '/discovery', '')
output projectConnectionString string = '${projectEndoint};${subscription().subscriptionId};${resourceGroup().name};${project.name}'

output bingSearchConnectionName string = bingSearchConnection.name

output weatherAPIConnectionName string = weatherAPIConnection.name
output weatherAPIConnectionId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.MachineLearningServices/workspaces/${project.name}/connections/${weatherAPIConnection.name}'

output placeOrderAPIConnectionName string = placeOrderAPIConnection.name
output placeOrderAPIConnectionId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.MachineLearningServices/workspaces/${project.name}/connections/${placeOrderAPIConnection.name}'

output productCatalogAPIConnectionName string = productCatalogAPIConnection.name
output productCatalogAPIConnectionId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.MachineLearningServices/workspaces/${project.name}/connections/${productCatalogAPIConnection.name}'

output applicationInsightsAppId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name
output apimResourceGatewayURL string = apimService.properties.gatewayUrl
