/**
 * @module apim-v1
 * @description This module defines the Azure API Management (APIM) resources using Bicep.
 * It includes configurations for creating and managing APIM instances, APIs, products, and policies.
 * This is version 1 (v1) of the APIM Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the API Management instance.')
param apiManagementName string

@description('The location of the API Management instance. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The email address of the publisher.')
param publisherEmail string

@description('The name of the publisher.')
param publisherName string

@description('Name of the APIM Logger')
param apimLoggerName string = 'apim-logger'

@description('Description of the APIM Logger')
param apimLoggerDescription string  = 'APIM Logger for OpenAI API'

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param apimSku string = 'Consumption'

@description('The XML content for the API policy')
param policyXml string

@description('Configuration array for OpenAI resources')
param openAIConfig array = []

@description('The name of the OpenAI API in API Management')
param openAIAPIName string

@description('The description of the OpenAI API in API Management')
param openAIAPIDescription string

@description('The display name of the OpenAI API in API Management')
param openAIAPIDisplayName string

@description('The path of the OpenAI API in API Management')
param openAIAPIPath string

@description('The URL for the OpenAI API specification')
param openAIAPISpecURL string

@description('The name of the OpenAI backend pool')
param openAIBackendPoolName string

@description('The description of the OpenAI backend pool')
param openAIBackendPoolDescription string

@description('The name of the OpenAI subscription in API Management')
param openAISubscriptionName string

@description('The description of the OpenAI subscription in API Management')
param openAISubscriptionDescription string

@description('The instrumentation key for Application Insights')
param appInsightsInstrumentationKey string

@description('The resource ID for Application Insights')
param appInsightsId string

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

// https://learn.microsoft.com/en-us/azure/templates/microsoft.apimanagement/service
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementName
  location: location
  sku: {
    name: apimSku
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
  identity: {
    type: 'SystemAssigned'
  }
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

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: apimLoggerName
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    description: apimLoggerDescription
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: appInsightsId
  }
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if (!empty(apimLogger.name)) {
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
output principalId string = apimService.identity.principalId
output gatewayUrl string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output subscriptionPrimaryKey string = apimSubscription.listSecrets().primaryKey
