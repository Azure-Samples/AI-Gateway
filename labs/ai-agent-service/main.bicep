// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apimSku string

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

var openAIPolicyXML = loadTextContent('openai-policy.xml')

var inferenceAPIPolicyXML = loadTextContent('inference-policy.xml')

var logSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens' , 'x-ratelimit-remaining-requests' ]
  body: { bytes: 8192 }
}

// ------------------
//    RESOURCES
// ------------------

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

resource azureOpenAIService 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
    name: 'openai1-${resourceSuffix}'
    location: location
    sku: {
      name: 'S0'
    }
    kind: 'AIServices'
    properties: {
      // required to work in AI Foundry
      allowProjectManagement: true 
      customSubDomainName: toLower('openai1-${resourceSuffix}')
      disableLocalAuth: false
    }
}

resource openAIDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
    name: 'openai-${modelsConfig[0].name}'
    parent: azureOpenAIService
    properties: {
      model: {
        format: modelsConfig[0].publisher
        name: modelsConfig[0].name
        version: modelsConfig[0].version
      }
    }
    sku: {
      name: 'Standard'
      capacity: modelsConfig[0].capacity
    }
  }

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: azureOpenAIService
    name: guid(subscription().id, resourceGroup().id, azureOpenAIService.name, cognitiveServicesUserRoleDefinitionID)
    properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleDefinitionID)
      principalId: apimService.identity.principalId
      principalType: 'ServicePrincipal'
    }
}

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: 'foundry-${resourceSuffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    // required to work in AI Foundry
    allowProjectManagement: true 

    // Defines developer API endpoint subdomain
    customSubDomainName: 'foundry-${resourceSuffix}'

    disableLocalAuth: false
  }
}

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  name: 'project-${resourceSuffix}'
  parent: aiFoundry
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

var aiProjectManagerRoleDefinitionID = 'eadc314b-1a2d-4efa-be10-5d325db5065e' 
resource aiProjectManagerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: aiFoundry
    name: guid(subscription().id, resourceGroup().id, azureOpenAIService.name, aiProjectManagerRoleDefinitionID)
    properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', aiProjectManagerRoleDefinitionID)
      principalId: deployer().objectId
    }
}

@batchSize(1)
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [for model in modelsConfig: if(length(modelsConfig) > 0) {
  name: model.name
  parent: aiFoundry
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

resource openAIConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'azure-openai-connection'
  parent: aiFoundry
  properties: {
    category: 'AzureOpenAI'
    target: '${apimService.properties.gatewayUrl}/'
    authType: 'ApiKey'
    credentials: {
        key: apimSubscription.listSecrets().primaryKey
    }
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: azureOpenAIService.id
    }
  }
}


resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview' = {
  name: '${aiFoundry.name}-capHost'
  parent: aiFoundry
  properties: {
    capabilityHostKind: 'Agents'
  }
  dependsOn: [
    aiProject
  ]
}

// Set the project capability host
resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  name: '${aiProject.name}-capHost'
  parent: aiProject
  properties: {
    capabilityHostKind: 'Agents'
    aiServicesConnections: ['${openAIConnection.name}']
  }
  dependsOn: [
    accountCapabilityHost
  ]
}


// Conditionally creates a new Azure AI Search resource
resource bingSearch 'Microsoft.Bing/accounts@2020-06-10' = {
  name: 'bingsearch-${resourceSuffix}'
  location: 'global'
  sku: {
    name: 'G1'
  }
  properties: {
    statisticsEnabled: false
  }
  kind: 'Bing.Grounding'
}

// Creates the Azure Foundry connection to your Azure App Insights resource
resource bingSearchConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: '${bingSearch.name}-connection'
  parent: aiFoundry
  properties: {
    category: 'ApiKey'
    target: 'https://api.bing.microsoft.com/'
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: bingSearch.listKeys().key1
    }
    metadata: {
      ApiType: 'Azure'
      Type: 'bing_grounding'
      ResourceId: bingSearch.id
    }
  }
}

resource weatherAPIConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'WeatherAPI'
  parent: aiFoundry
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

resource placeOrderAPIConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'PlaceOrderAPI'
  parent: aiFoundry
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

resource productCatalogAPIConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'ProductCatalogAPI'
  parent: aiFoundry
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
resource aiServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(length(modelsConfig) > 0) {
  name: 'aiservices-diagnostics'
  scope: aiFoundry
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


var cognitiveServicesUserRoleDefinitionID = 'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services User
resource aiServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(length(modelsConfig) > 0) {
  name: guid(subscription().id, resourceGroup().id, aiFoundry.name, cognitiveServicesUserRoleDefinitionID)
  scope: aiFoundry
  properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleDefinitionID)
      principalId: apimService.identity.principalId
      principalType: 'ServicePrincipal'
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource openAIAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'openai-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'OpenAI Inference API - ${aiFoundry.name}'
    displayName: 'OpenAI'
    format: 'openapi+json'
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
    value: string(loadJsonContent('../../modules/apim/v1/specs/AIFoundryOpenAI.json'))
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource inferenceAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = if(length(modelsConfig) > 0) {
  name: 'inference-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'Inference API - ${aiFoundry.name}'
    displayName: 'InferenceAPI'
    format: 'openapi+json'
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
    value: string(loadJsonContent('../../modules/apim/v1/specs/AIFoundryAzureAI.json'))
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
resource openAIAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: openAIAPI
  properties: {
    format: 'rawxml'
    value: openAIPolicyXML
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
resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'openai-backend'
  parent: apimService
  properties: {
    description: 'Backend for the OpenAI API'
    url: '${azureOpenAIService.properties.endpoint}/openai'
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
    credentials: {
      managedIdentity: {
          resource: 'https://cognitiveservices.azure.com'
      }
    }
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendInferenceAPI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = if(length(modelsConfig) > 0) {
  name: 'inference-backend'
  parent: apimService
  properties: {
    description: 'Backend for the inference API'
    url: '${aiFoundry.properties.endpoint}/models'
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

resource OpenAPIAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
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
output projectEndpoint string = 'https://${aiFoundry.name}.services.ai.azure.com/api/projects/${aiProject.name}'
//output projectConnectionString string = '${projectEndoint};${subscription().subscriptionId};${resourceGroup().name};${project.name}'

//output bingSearchConnectionName string = bingSearchConnection.name

output weatherAPIConnectionName string = weatherAPIConnection.name
//output weatherAPIConnectionId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.MachineLearningServices/workspaces/${project.name}/connections/${weatherAPIConnection.name}'

output placeOrderAPIConnectionName string = placeOrderAPIConnection.name
//output placeOrderAPIConnectionId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.MachineLearningServices/workspaces/${project.name}/connections/${placeOrderAPIConnection.name}'

output productCatalogAPIConnectionName string = productCatalogAPIConnection.name
//output productCatalogAPIConnectionId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.MachineLearningServices/workspaces/${project.name}/connections/${productCatalogAPIConnection.name}'

output applicationInsightsAppId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name
output apimResourceGatewayURL string = apimService.properties.gatewayUrl


