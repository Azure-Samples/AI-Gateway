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
param lawId string

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

// ------------------
//    RESOURCES
// ------------------

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2021-10-01' = [for config in openAIConfig: if(length(openAIConfig) > 0) {
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
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: '${cognitiveServices[i].name}-diagnostics'
  scope: cognitiveServices[i]
  properties: {
    workspaceId: lawId
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}]

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01'  =  [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
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

// ------------------
//    OUTPUTS
// ------------------

output extendedOpenAIConfig array = [for (config, i) in openAIConfig: {
  name: config.name
  location: config.location
  sku: openAISku
  deploymentName: openAIDeploymentName
  modelName: openAIModelName
  modelVersion: openAIModelVersion
  modelCapacity: openAIModelCapacity
  cognitiveService: cognitiveServices[i]
  endpoint: cognitiveServices[i].properties.endpoint
}]
