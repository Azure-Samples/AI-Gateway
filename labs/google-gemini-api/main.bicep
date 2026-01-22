// ------------------
//    PARAMETERS
// ------------------

param apimSku string
param apimSubscriptionsConfig array = []
param geminiAPIPath string = 'gemini/openai'

@secure()
param geminiApiKey string

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var policyXml = loadTextContent('policy.xml')
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

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: 'apim-${resourceSuffix}'
  dependsOn: [
    lawModule
    apimModule
  ]
}

// Named Value to securely store the Gemini API Key
// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/namedvalues
resource geminiApiKeyNV 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apimService
  name: 'gemini-api-key'
  properties: {
    displayName: 'gemini-api-key'
    secret: true
    value: 'Bearer ${geminiApiKey}'
    tags: [
      'gemini'
    ]
  }
}

// Backend for the Gemini OpenAI-compatible endpoint
// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendGemini 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'gemini-backend'
  parent: apimService
  properties: {
    description: 'Backend for the Google Gemini API (OpenAI-compatible)'
    url: 'https://generativelanguage.googleapis.com/v1beta/openai'
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
              {
                min: 500
                max: 503
              }
            ]
          }
          name: 'geminiCircuitBreakerRule'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
    credentials: {
      header: {
        Authorization: ['{{gemini-api-key}}']
      }
    }
  }
  dependsOn: [
    geminiApiKeyNV
    apimService
  ]
}

// OpenAI-compatible API for Gemini
// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource geminiOpenAIAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'gemini-openai-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'OpenAI-compatible API for Google Gemini models'
    displayName: 'Gemini - OpenAI Compatible'
    format: 'openapi+json-link'
    path: geminiAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: 'https://raw.githubusercontent.com/nourshaker-msft/sk_a2a_mcp/refs/heads/main/openai-openapi.json'
  }
  dependsOn: [
    apimService
    backendGemini
  ]
}

// API Policy for Gemini
// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource geminiAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: geminiOpenAIAPI
  properties: {
    format: 'rawxml'
    value: policyXml
  }
  dependsOn: [
    geminiApiKeyNV
    backendGemini
  ]
}

// API Diagnostics for logging
resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  name: 'applicationinsights'
  parent: geminiOpenAIAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apimService.name, 'appinsights-logger')
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

output logAnalyticsWorkspaceId string = lawModule.outputs.id
output applicationInsightsName string = appInsightsModule.outputs.name
output apimServiceId string = apimModule.outputs.id
output apimResourceName string = apimModule.outputs.name
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions string = string(apimModule.outputs.apimSubscriptions)
