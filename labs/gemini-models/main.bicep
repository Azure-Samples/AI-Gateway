// ------------------
//    PARAMETERS
// ------------------

param apimSku string
param apimSubscriptionsConfig array = []
param geminiInferenceAPIPath string = 'geminiapi' // Path to the inference API in the APIM service
param openAICompatibleAPIPath string = 'openaicompatible' // Path to the inference API in the APIM service
param geminiAPIURL string
param geminiAPIKey string

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
module apimModule '../../modules/apim/v3/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

var resourceSuffix string = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName string = 'apim-${resourceSuffix}'
var logSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens' , 'x-ratelimit-remaining-requests' ]
  body: { bytes: 8192 }
}

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    apimModule
  ]
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource geminiAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'gemini-inference-api'
  parent: apim
  properties: {
    apiType: 'http'
    description: 'Gemini Inference API'
    displayName: 'Gemini Inference API'
    format: 'openapi+json'
    path: geminiInferenceAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'x-goog-api-key'
      query: 'x-goog-api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: string(loadJsonContent('../../modules/apim/v3/specs/PassThrough.json')
  )}
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendGeminiAPI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'gemini-backend'
  parent: apim
  properties: {
    description: 'Gemini backend'
    url: geminiAPIURL
    protocol: 'http'
    credentials: {
      header: {
        'x-goog-api-key': [ // needed for Gemini API access
          geminiAPIKey
        ]
      }
    }    
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
          name: 'geminiBreakerRule'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource geminiAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: geminiAPI
  properties: {
    format: 'rawxml'
    value: replace(loadTextContent('policy.xml'), '{backend-id}', 'gemini-backend')
  }
}

resource geminiAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: geminiAPI
  name: 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: apimModule.outputs.loggerId
    sampling: {
      samplingType: 'fixed'
      percentage: json('100')
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    largeLanguageModel: {
      logs: 'enabled'
      requests: {
        messages: 'all'
        maxSizeInBytes: 262144
      }
      responses: {
        messages: 'all'
        maxSizeInBytes: 262144
      }
    }
  }
} 

resource geminiAPIDiagnosticsAppInsights 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: geminiAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apiManagementName, 'appinsights-logger')
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

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource openAIAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'openai-inference-api'
  parent: apim
  properties: {
    apiType: 'http'
    description: 'OpenAI Inference API'
    displayName: 'OpenAI Inference API'
    format: 'openapi+json'
    path: openAICompatibleAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
      #disable-next-line BCP037
      bearer: 'enabled'
    }
    subscriptionRequired: true
    type: 'http'
    value: string(loadJsonContent('../../modules/apim/v3/specs/PassThrough.json')
  )}
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendGeminiWithOpenAICompatibility 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'gemini-backend-with-openai-compatibility'
  parent: apim
  properties: {
    description: 'Gemini backend'
    url: geminiAPIURL
    protocol: 'http'
    credentials: {
      header: {
        Authorization: [ // needed for the OpeAI compatible endpoints
          'Bearer ${geminiAPIKey}'
        ]
      }
    }    
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
          name: 'geminiBreakerRule'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource openAIAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: openAIAPI
  properties: {
    format: 'rawxml'
    value: replace(loadTextContent('policy.xml'), '{backend-id}', 'gemini-backend-with-openai-compatibility')
  }
}

resource openAIAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: openAIAPI
  name: 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: apimModule.outputs.loggerId
    sampling: {
      samplingType: 'fixed'
      percentage: json('100')
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    largeLanguageModel: {
      logs: 'enabled'
      requests: {
        messages: 'all'
        maxSizeInBytes: 262144
      }
      responses: {
        messages: 'all'
        maxSizeInBytes: 262144
      }
    }
  }
} 

resource openAIAPIDiagnosticsAppInsights 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: openAIAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apiManagementName, 'appinsights-logger')
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

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

output apimSubscriptions array = apimModule.outputs.apimSubscriptions
