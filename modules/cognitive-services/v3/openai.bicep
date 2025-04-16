/**
 * @module openai-v2
 * @description This module defines the Azure Cognitive Services OpenAI resources using Bicep.
 * This is version 2 (v2) of the OpenAI Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Azure OpenAI Sku')
@allowed([
  'S0'
])
param openAISku string = 'S0'

@description('Azure OpenAI Deployment Name')
param openAIDeploymentName string

@description('Model Name')
param openAIModelName string

@description('Model Version')
param openAIModelVersion string

@description('Model SKU')
param openAIModelSKU string = 'Standard'

@description('Configuration array for OpenAI resources')
param openAIConfig array = []

@description('Log Analytics Workspace Id')
param lawId string = ''

@description('APIM Pricipal Id')
param apimPrincipalId string

@description('Enable Private Endpoint for AI Services')
param enablePrivateEndpoint bool = false

@description('Virtual Network Id for Private DNS Zone Link')
param vnetId string = ''

@description('Subnet Id for Private Endpoint')
param subnetId string = ''


// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var azureRoles = loadJsonContent('../../azure-roles.json')
var cognitiveServicesOpenAIUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)

var privateDnsZoneNamesAiServices = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
]

// ------------------
//    RESOURCES
// ------------------

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = [for config in openAIConfig: if(length(openAIConfig) > 0) {
  name: '${config.name}-${resourceSuffix}'
  location: config.location
  sku: {
    name: openAISku
  }
  kind: 'AIServices'
  properties: {
    customSubDomainName: toLower('${config.name}-${resourceSuffix}')
    publicNetworkAccess: 'Enabled'
    apiProperties: {
      statisticsEnabled: false
    }
  }
}]

// https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0 && lawId != '') {
  name: '${cognitiveServices[i].name}-diagnostics'
  scope: cognitiveServices[i]
  properties: {
    workspaceId: lawId != '' ? lawId : null
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}]

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: openAIDeploymentName
  parent: cognitiveServices[i]
  properties: {
    model: {
      format: 'OpenAI'
      name: openAIModelName
      version: openAIModelVersion
    }
  }
  sku: {
      name: openAIModelSKU
      capacity: config.capacity
  }
}]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  scope: cognitiveServices[i]
  name: guid(subscription().id, resourceGroup().id, config.name, cognitiveServicesOpenAIUserRoleDefinitionID)
    properties: {
        roleDefinitionId: cognitiveServicesOpenAIUserRoleDefinitionID
        principalId: apimPrincipalId
        principalType: 'ServicePrincipal'
    }
}]

// Create private endpoint if enabled
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0 && enablePrivateEndpoint) {
  name: '${config.name}-${resourceSuffix}-privateEndpoint'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: subnetId    
    }
    privateLinkServiceConnections: [
      {
        name: '${config.name}-${resourceSuffix}-privateLinkServiceConnection'
        properties: {
          privateLinkServiceId: cognitiveServices[i].id
          groupIds: ['account']
        }
      }
    ]
  }
}]

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [for (privateDnsZoneName, i) in privateDnsZoneNamesAiServices: if(length(privateDnsZoneNamesAiServices) > 0) {
  name: privateDnsZoneName
  location: 'global'
}]

// link private DNS zone to the virtual network
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (privateDnsZoneName, i) in privateDnsZoneNamesAiServices: if(length(privateDnsZoneNamesAiServices) > 0) {
  name: '${privateDnsZoneName}-link'
  location: 'global'
  parent: privateDnsZone[i]
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]

// privateDnsZoneGroups for private endpoints
resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = [for (privateDnsZoneName, i) in privateDnsZoneNamesAiServices: if(length(privateDnsZoneNamesAiServices) > 0) {
  name: '${privateDnsZoneName}-dnsZoneGroup'
  parent: privateEndpoint[i]
  properties: {
    privateDnsZoneConfigs: [
      for (privateDnsZoneName, j) in privateDnsZoneNamesAiServices: {
        name: 'config${j}'
        properties: {
          privateDnsZoneId: privateDnsZone[j].id
        }
      }
    ]
  }
}]

// ------------------
//    OUTPUTS
// ------------------

output extendedOpenAIConfig array = [for (config, i) in openAIConfig: {
  // Original openAIConfig properties
  name: config.name
  location: config.location
  priority: config.?priority
  weight: config.?weight
  // Additional properties
  sku: openAISku
  deploymentName: openAIDeploymentName
  modelName: openAIModelName
  modelVersion: openAIModelVersion
  cognitiveService: cognitiveServices[i]
  endpoint: cognitiveServices[i].properties.endpoint
}]
