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
param openAIAPIVersion string = '2024-02-01'

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

var apimLoggerName = 'apim-logger'
var logSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens' , 'x-ratelimit-remaining-requests' ]
  body: { bytes: 8192 }
}

// Account for all placeholders in the polixy.xml file.
var policyXml = loadTextContent('policy.xml')
var updatedPolicyXml = replace(policyXml, '{backend-id}', (length(openAIConfig) > 1) ? 'openai-backend-pool' : openAIConfig[0].name)

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
    lawId: lawId
    customMetricsOptedInType: 'WithDimensions'
  }
}

var appInsightsId = appInsightsModule.outputs.id
var appInsightsInstrumentationKey = appInsightsModule.outputs.instrumentationKey

// 3. API Management
module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
  }
}

// 4. Cognitive Services
module openAIModule '../../modules/cognitive-services/v1/openai.bicep' = {
    name: 'openAIModule'
    params: {
      openAIConfig: openAIConfig
      openAIDeploymentName: openAIDeploymentName
      openAIModelName: openAIModelName
      openAIModelVersion: openAIModelVersion
      openAIModelSKU: openAIModelSKU
      apimPrincipalId: apimModule.outputs.principalId
      lawId: lawId
    }
  }

// 5. APIM OpenAI API
module openAIAPIModule '../../modules/apim/v1/openai-api.bicep' = {
  name: 'openAIAPIModule'
  params: {
    policyXml: updatedPolicyXml
    openAIConfig: openAIModule.outputs.extendedOpenAIConfig
    openAIAPIVersion: openAIAPIVersion
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
  }
}

// We presume the APIM resource has been created as part of this bicep flow.
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    apimModule
  ]
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

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource weatherAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'weather-api'
  parent: apim
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
  parent: apim
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
  parent: apim
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

resource openAISubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'openai-subscription'
  parent: apim
  properties: {
    allowTracing: true
    displayName: 'OpenAI Inference API Subscription'
    scope: '/apis'
    state: 'active'
  }
}

resource toolsSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'tools-subscription'
  parent: apim
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

output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName
output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output openAISubscriptionKey string = openAISubscription.listSecrets().primaryKey
#disable-next-line outputs-should-not-contain-secrets
output toolsSubscriptionKey string = toolsSubscription.listSecrets().primaryKey
