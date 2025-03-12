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

param inferenceAPISubscriptionPrimaryKey string = newGuid()
param inferenceAPISubscriptionSecondaryKey string = newGuid()

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'

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

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource inferenceAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'inference-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'Inference API - ${openAIDeployment[0].name}'
    displayName: 'InferenceAPI'
    format: 'openapi+json'
    path: 'models'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'Authorization'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: loadTextContent('inference-openapi.json')
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
resource inferenceAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
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
resource backendInferenceAPI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'inference-backend'
  parent: apimService
  properties: {
    description: 'Backend for the inference API'
    url: '${openAIAccount[0].properties.endpoint}/openai/deployments/${openAIDeploymentName}'
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

resource inferenceAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
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

resource inferenceAPISubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'inference-api-subscription'
  parent: apimService
  properties: {
    allowTracing: true
    displayName: 'Inference API Subscription'
    scope: '/apis'
    state: 'active'
    primaryKey: 'Bearer ${inferenceAPISubscriptionPrimaryKey}'
    secondaryKey: 'Bearer ${inferenceAPISubscriptionSecondaryKey}'
  }
}

resource toolsSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'tools-subscription'
  parent: apimService
  properties: {
    allowTracing: true
    displayName: 'Tools APIs Subscription'
    scope: '/apis'
    state: 'active'
  }
}


// ------------------
//    OUTPUTS
// ------------------

output applicationInsightsAppId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name
output apimResourceGatewayURL string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output inferenceAPISubscriptionKey string = inferenceAPISubscription.listSecrets().primaryKey

#disable-next-line outputs-should-not-contain-secrets
output toolsSubscriptionKey string = toolsSubscription.listSecrets().primaryKey
