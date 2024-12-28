/**
 * @module content-safety-v1
 * @description This module defines the Azure Cognitive Services Content Safety resources using Bicep.
 * This is version 1 (v1) of the Content Safety Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the AI Content Safety resource')
param contentSafetyName string = 'contentsafety'

@description('Location of the AI Content Safety resource')
param contentSafetyLocation string = resourceGroup().location

@description('SKU of the AI Content Safety resource')
param contentSafetySKU string = 'S0'

// @description('Azure OpenAI Deployment Name')
// param openAIDeploymentName string

// @description('Model Name')
// param openAIModelName string

// @description('Model Version')
// param openAIModelVersion string

// @description('Model Capacity')
// param openAIModelCapacity int = 20

// @description('Configuration array for OpenAI resources')
// param openAIConfig array = []

// @description('Log Analytics Workspace Id')
// param lawId string = ''

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

// ------------------
//    RESOURCES
// ------------------

resource contentSafety 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: '${contentSafetyName}-${resourceSuffix}'
  location: contentSafetyLocation
  sku: {
    name: contentSafetySKU
  }
  kind: 'ContentSafety'
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: toLower('${contentSafetyName}-${resourceSuffix}')
  }
}

// resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = [for config in openAIConfig: if(length(openAIConfig) > 0) {
//   name: '${config.name}-${resourceSuffix}'
//   location: config.location
//   sku: {
//     name: openAISku
//   }
//   kind: 'OpenAI'
//   properties: {
//     apiProperties: {
//       statisticsEnabled: false
//     }
//     customSubDomainName: toLower('${config.name}-${resourceSuffix}')
//   }
// }]

// // https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/diagnosticsettings
// resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0 && lawId != '') {
//   name: '${cognitiveServices[i].name}-diagnostics'
//   scope: cognitiveServices[i]
//   properties: {
//     workspaceId: lawId != '' ? lawId : null
//     logs: []
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//       }
//     ]
//   }
// }]

// resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
//     name: openAIDeploymentName
//     parent: cognitiveServices[i]
//     properties: {
//       model: {
//         format: 'OpenAI'
//         name: openAIModelName
//         version: openAIModelVersion
//       }
//     }
//     sku: {
//         name: 'Standard'
//         capacity: openAIModelCapacity
//     }
// }]

// ------------------
//    OUTPUTS
// ------------------

output contentSafetyEndpoint string = contentSafety.properties.endpoint
