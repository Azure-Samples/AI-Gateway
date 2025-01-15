/**
 * @module openai-v1
 * @description This module defines the Azure Cognitive Services OpenAI resources using Bicep.
 * This is version 1 (v1) of the OpenAI Bicep module.
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

@description('Model Capacity')
param openAIModelCapacity int = 20

@description('Configuration array for OpenAI resources')
param openAIConfig array = []

@description('Log Analytics Workspace Id')
param lawId string = ''

@description('APIM Pricipal Id')
param  apimPrincipalId string

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var azureRoles = loadJsonContent('../../azure-roles.json')
var cognitiveServicesOpenAIUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)


// ------------------
//    RESOURCES
// ------------------

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = [for config in openAIConfig: if(length(openAIConfig) > 0) {
  name: '${config.name}-${resourceSuffix}'
  location: config.location
  sku: {
    name: openAISku
  }
  kind: 'OpenAI'
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
    customSubDomainName: toLower('${config.name}-${resourceSuffix}')
  }
}]

// https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/diagnosticsettings
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
      name: 'Standard'
      capacity: openAIModelCapacity
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
  modelCapacity: openAIModelCapacity
  cognitiveService: cognitiveServices[i]
  endpoint: cognitiveServices[i].properties.endpoint
}]
