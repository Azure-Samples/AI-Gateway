/**
 * @module openai-v2
 * @description This module defines the Azure Cognitive Services OpenAI resources using Bicep.
 * This is version 2 (v2) of the OpenAI Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------


@description('Configuration array for AI Foundry resources')
param aiServicesConfig array = []

@description('Configuration array for the model deployments')
param modelsConfig array = []

@description('Log Analytics Workspace Id')
param lawId string = ''

@description('APIM Pricipal Id')
param  apimPrincipalId string

@description('AI Foundry project name')
param  foundryProjectName string = 'default'

@description('The instrumentation key for Application Insights')
@secure()
param appInsightsInstrumentationKey string = ''

@description('The resource ID for Application Insights')
param appInsightsId string = ''


// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var azureRoles = loadJsonContent('../../azure-roles.json')
var cognitiveServicesUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesUser)


// ------------------
//    RESOURCES
// ------------------

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2025-06-01' = [for config in aiServicesConfig: {
  name: '${config.name}-${resourceSuffix}'
  location: config.location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    // required to work in AI Foundry
    allowProjectManagement: true 

    customSubDomainName: toLower('${config.name}-${resourceSuffix}')

    disableLocalAuth: false

    publicNetworkAccess: 'Enabled'
  }  
}]

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = [for (config, i) in aiServicesConfig: {  
  #disable-next-line BCP334
  name: '${foundryProjectName}-${config.name}'
  parent: cognitiveServices[i]
  location: config.location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}]


var aiProjectManagerRoleDefinitionID = 'eadc314b-1a2d-4efa-be10-5d325db5065e' 
resource aiProjectManagerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in aiServicesConfig: {
    scope: cognitiveServices[i]
    name: guid(subscription().id, resourceGroup().id, config.name, aiProjectManagerRoleDefinitionID)
    properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', aiProjectManagerRoleDefinitionID)
      principalId: deployer().objectId
    }
}]


// https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (config, i) in aiServicesConfig: if (lawId != '') {
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

resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = [for (config, i) in aiServicesConfig: if (length(appInsightsId) > 0 && length(appInsightsInstrumentationKey) > 0) {
  parent: cognitiveServices[i]
  name: '${cognitiveServices[i].name}-appInsights-connection'
  properties: {
    authType: 'ApiKey'
    category: 'AppInsights'
    target: appInsightsId
    useWorkspaceManagedIdentity: false
    isSharedToAll: false
    sharedUserList: []
    peRequirement: 'NotRequired'
    peStatus: 'NotApplicable'
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsightsId
    }
    credentials: {
      key: appInsightsInstrumentationKey
    }    
  }
}]

resource roleAssignmentCognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in aiServicesConfig: {
  scope: cognitiveServices[i]
  name: guid(subscription().id, resourceGroup().id, config.name, cognitiveServicesUserRoleDefinitionID)
    properties: {
        roleDefinitionId: cognitiveServicesUserRoleDefinitionID
        principalId: apimPrincipalId
        principalType: 'ServicePrincipal'
    }
}]

module modelDeployments 'deployments.bicep' = [for (config, i) in aiServicesConfig: {
  name: take('models-${cognitiveServices[i].name}', 64)
  params: {
    cognitiveServiceName: cognitiveServices[i].name
    modelsConfig: modelsConfig
  }
}]


// ------------------
//    OUTPUTS
// ------------------

output extendedAIServicesConfig array = [for (config, i) in aiServicesConfig: {
  // Original openAIConfig properties
  name: config.name
  location: config.location
  priority: config.?priority
  weight: config.?weight
  // Additional properties
  cognitiveService: cognitiveServices[i]
  cognitiveServiceName: cognitiveServices[i].name
  endpoint: cognitiveServices[i].properties.endpoint
  foundryProjectEndpoint: 'https://${cognitiveServices[i].name}.services.ai.azure.com/api/projects/${aiProject[i].name}'
}]
