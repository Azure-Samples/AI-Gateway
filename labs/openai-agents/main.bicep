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

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'
var apimLoggerName = 'appinsights-logger'
var logSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens' , 'x-ratelimit-remaining-requests' ]
  body: { bytes: 8192 }
}

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawModule.outputs.id
    customMetricsOptedInType: 'WithDimensions'
  }
}

// 3. API Management
module apimModule '../../modules/apim/v2/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
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

// 5. APIM Inference API
module inferenceAPIModule '../../modules/apim/v2/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}


// We presume the APIM resource has been created as part of this bicep flow.
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    inferenceAPIModule
  ]
}

resource placeOrderWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'ordersworkflow-${resourceSuffix}'
  location: resourceGroup().location
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

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource weatherAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'weather-api'
  parent: apim
  properties: {
    apiType: 'http'
    description: 'City Weather API'
    displayName: 'City Weather API'
    format: 'openapi+json'
    path: 'weatherservice'
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
  parent: apim
  properties: {
    apiType: 'http'
    description: 'Place Order API'
    displayName: 'Place Order API'
    format: 'openapi+json'
    path: 'orderservice'
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
  parent: apim
  properties: {
    apiType: 'http'
    description: 'Product Catalog API'
    displayName: 'Product Catalog API'
    format: 'openapi+json'
    path: 'catalogservice'
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
resource backendPlaceOrderAPI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'orderworflow-backend'
  parent: apim
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


// ------------------
//    OUTPUTS
// ------------------

output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName
output logAnalyticsWorkspaceId string = lawModule.outputs.customerId

output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
