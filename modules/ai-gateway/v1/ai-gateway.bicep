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

@description('The name of the API Management instance. Defaults to "aigw-<resourceSuffix>".')
param apiManagementName string = 'aigw-${resourceSuffix}'

@description('The location of the API Management instance. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Tags to be applied to the API Management instance.')
param tags object = {}

@description('The email address of the publisher. Defaults to "noreply@microsoft.com".')
param publisherEmail string = 'noreply@microsoft.com'

@description('The name of the publisher. Defaults to "Microsoft".')
param publisherName string = 'Microsoft'

@description('The type of managed identity to by used with API Management')
@allowed([
  'SystemAssigned'
  'UserAssigned'
  'SystemAssigned, UserAssigned'
])
param apimManagedIdentityType string = 'SystemAssigned'

@description('The user-assigned managed identity ID to be used with API Management')
param apimUserAssignedManagedIdentityId string = ''

@description('The name of the default workspace to be created in API Management. Defaults to "default".')
param workspaceName string = 'default'

@description('Configuration array for API Keys')
param apiKeysConfig array = []

@description('The resource ID for Application Insights')
param appInsightsId string = ''

@description('Indicates whether payload capture is enabled for telemetry exporters. Defaults to false.')
param payloadCapture bool = false

@description('The Foundry accounts to be used with API Management.')
param foundryAccountsConfig array

@description('The managed identity resource for the Foundry provider.')
param foundryManagedIdentityResource string = 'https://cognitiveservices.azure.com/'

@description('The tool server configurations to be registered with the default workspace.')
@secure()
param toolServerConfigs object = {}

// ------------------
//    VARIABLES
// ------------------

// ------------------
//    RESOURCES
// ------------------
resource aiGateway 'Microsoft.ApiManagement/service@2025-09-01-preview' = {
  name: apiManagementName
  location: location
  tags: tags
  identity: {
    type: apimManagedIdentityType
    userAssignedIdentities: apimManagedIdentityType == 'UserAssigned' && apimUserAssignedManagedIdentityId != '' ? {
      // BCP037: Not yet added to latest API:
      '${apimUserAssignedManagedIdentityId}': {}
    } : null
  }
  sku: {
    name: 'AIGateway'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource connectorNamespace 'Microsoft.Web/connectorGateways@2026-05-01-preview' = {
  name: apiManagementName
  location: location
  properties: {}
  dependsOn: [
    aiGateway
  ]
}

resource defaultWorkspace 'Microsoft.ApiManagement/service/workspaces@2025-09-01-preview' existing =  {
  name: workspaceName
  parent: aiGateway
}

module foundryUserRoleAssignments './foundry-user-role.bicep' = [for (foundryAccount, i) in foundryAccountsConfig: {
  name: 'foundry-rbac-${i}-${uniqueString(foundryAccount.cognitiveServicesId, apiManagementName)}'
  scope: resourceGroup(split(foundryAccount.cognitiveServicesId, '/')[2], split(foundryAccount.cognitiveServicesId, '/')[4])
  params: {
    foundryAccountName: last(split(foundryAccount.cognitiveServicesId, '/'))
    gatewayPrincipalId: aiGateway!.identity.principalId
    gatewayResourceId: aiGateway!.id
  }
}]

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: last(split(appInsightsId, '/'))
}

module monitoringMetricsPublisherRoleAssignments './metrics-publisher-role.bicep' = {
  name: 'monitoring-metrics-publisher-rbac-${uniqueString(appInsights.id, apiManagementName)}'
  scope: resourceGroup(split(appInsights.id, '/')[2], split(appInsights.id, '/')[4])
  params: {
    appInsightsId: appInsights.id
    gatewayPrincipalId: aiGateway!.identity.principalId
    gatewayResourceId: aiGateway!.id
  }
}

resource telemetryExporter 'Microsoft.ApiManagement/service/workspaces/telemetryExporters@2025-09-01-preview' = {
  parent: defaultWorkspace
  name: 'appinsights'
  properties: {
    kind: 'OpenTelemetry'
    payloadCapture: payloadCapture
    applicationInsights: {
      resourceId: appInsightsId
    }
    openTelemetry: {
      logsEndpoint: appInsights.properties.OTLPLogsEndpoint
      metricsEndpoint: appInsights.properties.OTLPMetricsEndpoint
      tracesEndpoint: appInsights.properties.OTLPTracesEndpoint
    }
  }
}

resource foundryProvider 'Microsoft.ApiManagement/service/workspaces/modelProviders@2025-09-01-preview' = [for foundryAccount in foundryAccountsConfig: {
  parent: defaultWorkspace
  name: length(foundryAccountsConfig) > 1 ? 'foundry-${foundryAccount.name}' : foundryAccount.name
  dependsOn: [
    foundryUserRoleAssignments
  ]
  properties: {
    kind: 'Foundry'
    displayName: length(foundryAccountsConfig) > 1 ? 'foundry-${foundryAccount.name}' : foundryAccount.name
    description: 'Foundry provider for ${foundryAccount.name}'
    foundry: {
      endpoint: foundryAccount.endpoint
      resourceIds: [ 
        foundryAccount.cognitiveServicesId
      ]
      authentication: {
        kind: 'ManagedIdentity'
        managedIdentity: {
          resource: foundryManagedIdentityResource
        }
      }
    }
  }
}]

module modelProvidersModule './model-providers.bicep' = [for (foundryAccount, i) in foundryAccountsConfig: {
  name: 'model-providers-${i}-${uniqueString(foundryAccount.cognitiveServicesId, apiManagementName)}'
  scope: resourceGroup()
  params: {
    foundryAccountName: length(foundryAccountsConfig) > 1 ? foundryAccount.name : ''
    apimName: apiManagementName
    workspaceName: defaultWorkspace.name
    modelProviderName: foundryProvider[i].name
    modelsConfig: foundryAccount.modelDeployments
  }
  dependsOn: [
    foundryProvider
  ]
}]

resource toolServers 'Microsoft.ApiManagement/service/workspaces/toolServers@2025-09-01-preview' = [for config in items(toolServerConfigs): {
  parent: defaultWorkspace
  name: config.key
  properties: config.value
}]

@batchSize(1)
resource runtimeApiKey 'Microsoft.ApiManagement/service/apiKeys@2025-09-01-preview' = [for apiKey in apiKeysConfig: {
  name: apiKey.name
  parent: aiGateway
  properties: {
    displayName: apiKey.displayName
  }
}]


// ------------------
//    OUTPUTS
// ------------------

output id string = aiGateway.id
output name string = aiGateway.name
output principalId string = (apimManagedIdentityType == 'SystemAssigned') ? aiGateway.identity.principalId : ''
output gatewayUrl string = aiGateway.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apiKeys array = [for (apiKey, i) in apiKeysConfig: {
  name: apiKey.name
  displayName: apiKey.displayName
  key: runtimeApiKey[i].listSecrets().primaryKey
}]

