/**
 * @module openai-api-v1
 * @description This module defines the Azure OpenAI APIs in the Azure API Management (APIM) resource using Bicep.
 * It includes configurations for creating and managing Azure OpenAI APIs, products, and policies.
 * This is version 1 (v1) of the Azure OpenAI API Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('The suffix to append to the API Management instance name. Defaults to a unique string based on subscription and resource group IDs.')
param resourceSuffix string = uniqueString(subscription().id, resourceGroup().id)

@description('The name of the API Management instance. Defaults to "apim-<resourceSuffix>".')
param apiManagementName string = 'apim-${resourceSuffix}'

@description('The XML content for the API policy')
param policyXml string

@description('Configuration array for OpenAI resources')
param openAIConfig array = []

@description('The name of the OpenAI API in API Management. Defaults to "openai".')
param openAIAPIName string = 'openai'

@description('The description of the OpenAI API in API Management. Defaults to "Azure OpenAI API inferencing API".')
param openAIAPIDescription string = 'Azure OpenAI API inferencing API'

@description('The display name of the OpenAI API in API Management. Defaults to "OpenAI".')
param openAIAPIDisplayName string = 'OpenAI'

@description('The path of the OpenAI API in API Management. Defaults to "openai".')
param openAIAPIPath string = 'openai'

@description('The version of the OpenAI API in API Management. Defaults to "2024-02-01".')
param openAIAPIVersion string = '2024-02-01'

@description('The URL for the OpenAI API specification')
param openAIAPISpecURL string = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/${openAIAPIVersion}/inference.json'

@description('The name of the OpenAI backend pool. Defaults to "openai-backend-pool".')
param openAIBackendPoolName string = 'openai-backend-pool'

@description('The description of the OpenAI backend pool. Defaults to "Load balancer for multiple OpenAI endpoints".')
param openAIBackendPoolDescription string = 'Load balancer for multiple OpenAI endpoints'

@description('The name of the OpenAI subscription in API Management. Defaults to "openai-subscription".')
param openAISubscriptionName string = 'openai-subscription'

@description('The description of the OpenAI subscription in API Management. Defaults to "OpenAI Subscription".')
param openAISubscriptionDescription string = 'OpenAI Subscription'

@description('Name of the APIM Logger')
param apimLoggerName string = 'apim-logger'

@description('The instrumentation key for Application Insights')
param appInsightsInstrumentationKey string = ''

@description('The resource ID for Application Insights')
param appInsightsId string = ''

// ------------------
//    VARIABLES
// ------------------

var logSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens' , 'x-ratelimit-remaining-requests' ]
  body: { bytes: 8192 }
}

// ------------------
//    RESOURCES
// ------------------

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' existing = {
  name: apimLoggerName
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.apimanagement/service/apis
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: openAIAPIName
  parent: apimService
  properties: {
    apiType: 'http'
    description: openAIAPIDescription
    displayName: openAIAPIDisplayName
    format: 'openapi-link'
    path: openAIAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: openAIAPISpecURL
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.apimanagement/service/apis/policies
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.apimanagement/service/backends
resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' =  [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: config.name
  parent: apimService
  properties: {
    description: 'backend description'
    url: '${config.endpoint}/openai'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 3
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
        }
      ]
    }
  }
}]

// https://learn.microsoft.com/en-us/azure/templates/microsoft.apimanagement/service/backends
resource backendPoolOpenAI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = if(length(openAIConfig) > 1) {
  name: openAIBackendPoolName
  parent: apimService
  // BCP035: protocol and url are not needed in the Pool type. This is an incorrect error.
  #disable-next-line BCP035
  properties: {
    description: openAIBackendPoolDescription
    type: 'Pool'
    pool: {
      services: [for (config, i) in openAIConfig: {
          id: '/backends/${backendOpenAI[i].name}'
        }
      ]
    }
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.apimanagement/service/subscriptions
resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: openAISubscriptionName
  parent: apimService
  properties: {
    allowTracing: true
    displayName: openAISubscriptionDescription
    scope: '/apis/${api.id}'
    state: 'active'
  }
}

// Create diagnostics only if we have an App Insights ID and instrumentation key.
// https://learn.microsoft.com/en-us/azure/templates/microsoft.apimanagement/service/apis/diagnostics
resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if (!empty(appInsightsId) && !empty(appInsightsInstrumentationKey)) {
  name: 'applicationinsights'
  parent: api
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: apimLogger.id
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

output id string = apimService.id
output name string = apimService.name
output principalId string = apimService.identity.principalId
output gatewayUrl string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output subscriptionPrimaryKey string = apimSubscription.listSecrets().primaryKey
