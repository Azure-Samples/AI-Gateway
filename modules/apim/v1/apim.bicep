/**
 * @module apim-v1
 * @description This module defines the Azure API Management (APIM) resources using Bicep.
 * It includes configurations for creating and managing APIM instances, APIs, products, and policies.
 * This is version 1 (v1) of the APIM Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('The suffix to append to the API Management instance name. Defaults to a unique string based on subscription and resource group IDs.')
param resourceSuffix string = uniqueString(subscription().id, resourceGroup().id)

@description('The name of the API Management instance. Defaults to "apim-<resourceSuffix>".')
param apiManagementName string = 'apim-${resourceSuffix}'

@description('The location of the API Management instance. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The email address of the publisher. Defaults to "noreply@microsoft.com".')
param publisherEmail string = 'noreply@microsoft.com'

@description('The name of the publisher. Defaults to "Microsoft".')
param publisherName string = 'Microsoft'

@description('Name of the APIM Logger')
param apimLoggerName string = ''

@description('Description of the APIM Logger')
param apimLoggerDescription string  = ''

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
param apimSku string = 'Basicv2'

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

@description('The instrumentation key for Application Insights')
param appInsightsInstrumentationKey string = ''

@description('The resource ID for Application Insights')
param appInsightsId string = ''

@description('The type of managed identity to by used with API Management')
@allowed([
  'SystemAssigned'
  'UserAssigned'
  'SystemAssigned, UserAssigned'
])
param apimManagedIdentityType string = 'SystemAssigned'

@description('The user-assigned managed identity ID to be used with API Management')
param apimUserAssignedManagedIdentityId string = ''

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
    type: apimManagedIdentityType
    userAssignedIdentities: apimManagedIdentityType == 'UserAssigned' && apimUserAssignedManagedIdentityId != '' ? {
      // BCP037: Not yet added to latest API:
      '${apimUserAssignedManagedIdentityId}': {}
    } : null
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

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (apimLoggerName != '') {
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
output name string = apimService.name
output principalId string = apimService.identity.principalId
output gatewayUrl string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output subscriptionPrimaryKey string = apimSubscription.listSecrets().primaryKey
