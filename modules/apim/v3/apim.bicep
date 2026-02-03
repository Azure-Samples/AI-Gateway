/**
 * @module apim-v1
 * @description This module defines the Azure API Management (APIM) resources using Bicep.
 * It includes configurations for creating and managing APIM instance.
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

@description('The type of managed identity to by used with API Management')
@allowed([
  'SystemAssigned'
  'UserAssigned'
  'SystemAssigned, UserAssigned'
])
param apimManagedIdentityType string = 'SystemAssigned'

@description('The user-assigned managed identity ID to be used with API Management')
param apimUserAssignedManagedIdentityId string = ''

@description('Configuration array for APIM subscriptions')
param apimSubscriptionsConfig array = []

@description('The Log Analytics Workspace ID for diagnostic settings')
param lawId string = ''

@description('The instrumentation key for Application Insights')
param appInsightsInstrumentationKey string = ''

@description('The resource ID for Application Insights')
param appInsightsId string = ''

@description('The release channel for the API Management service')
@allowed([
  'Early'
  'Default'
  'Late'
  'GenAI'
])
param releaseChannel string = 'Default'

// ------------------
//    VARIABLES
// ------------------


// ------------------
//    RESOURCES
// ------------------

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service
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
    releaseChannel: releaseChannel
  }
  identity: {
    type: apimManagedIdentityType
    userAssignedIdentities: apimManagedIdentityType == 'UserAssigned' && apimUserAssignedManagedIdentityId != '' ? {
      // BCP037: Not yet added to latest API:
      '${apimUserAssignedManagedIdentityId}': {}
    } : null
  }
}

resource apimDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(length(lawId) > 0) {
  scope: apimService
  name: 'apimDiagnosticSettings'
  properties: {
    workspaceId: lawId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = if(length(lawId) > 0) {
  parent: apimService
  name: 'azuremonitor'
  properties: {
    loggerType: 'azureMonitor'
    isBuffered: false // Set to false to ensure logs are sent immediately
  }
}

// Create a logger only if we have an App Insights ID and instrumentation key.
resource apimAppInsightsLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (!empty(appInsightsId) && !empty(appInsightsInstrumentationKey)) {
  name: 'appinsights-logger'
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    description: 'APIM Logger for Application Insights'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: appInsightsId
  }
}

@batchSize(1)
resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = [for subscription in apimSubscriptionsConfig: if(length(apimSubscriptionsConfig) > 0) {
  name: subscription.name
  parent: apimService
  properties: {
    allowTracing: true
    displayName: '${subscription.displayName}'
    scope: '/apis'
    state: 'active'
  }
}]


// ------------------
//    OUTPUTS
// ------------------

output id string = apimService.id
output name string = apimService.name
output principalId string = (apimManagedIdentityType == 'SystemAssigned') ? apimService.identity.principalId : ''
output gatewayUrl string = apimService.properties.gatewayUrl
output loggerId string = (length(lawId) > 0) ? apimLogger.id : ''

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptions array = [for (subscription, i) in apimSubscriptionsConfig: {
  name: subscription.name
  displayName: subscription.displayName
  key: apimSubscription[i].listSecrets().primaryKey
}]
