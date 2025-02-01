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
param apimSku string = 'Basicv2'

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
  }
  identity: {
    type: apimManagedIdentityType
    userAssignedIdentities: apimManagedIdentityType == 'UserAssigned' && apimUserAssignedManagedIdentityId != '' ? {
      // BCP037: Not yet added to latest API:
      '${apimUserAssignedManagedIdentityId}': {}
    } : null
  }
}

// Create a logger only if we have an App Insights ID and instrumentation key.
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (!empty(appInsightsId) && !empty(appInsightsInstrumentationKey)) {
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

// ------------------
//    OUTPUTS
// ------------------

output id string = apimService.id
output name string = apimService.name
output principalId string = apimService.identity.principalId
output gatewayUrl string = apimService.properties.gatewayUrl

