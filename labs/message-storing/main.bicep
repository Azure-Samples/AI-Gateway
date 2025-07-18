
// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference' // Path to the inference API in the APIM service
param foundryProjectName string = 'default'

@description('Event Hub namespace location')
param eventHubLocation string = resourceGroup().location

@description('Event Hub SKU')
param eventHubSKU string = 'Standard'

@description('Event Hub SKU capacity')
param eventHubSKUCapacity int = 1

@description('Event Hub name')
param eventHubName string = 'llm-messages'

@description('Streaming Jobs name')
param streamingJobsName string = 'llm-messages-streaming-job'

@description('The name for the database')
param cosmosDBDatabaseName string

@description('The name for the container')
param cosmosDBContainerName string

@description('The partition key for the container')
param partitionKeyPath string = '/model'

@description('The throughput policy for the container')
@allowed([
  'Manual'
  'Autoscale'
])
param throughputPolicy string = 'Autoscale'

@description('Throughput value when using Manual Throughput Policy for the container')
@minValue(400)
@maxValue(1000000)
param manualProvisionedThroughput int = 400

@description('Maximum throughput when using Autoscale Throughput Policy for the container')
@minValue(1000)
@maxValue(1000000)
param autoscaleMaxThroughput int = 1000

@description('Time to Live for data in analytical store. (-1 no expiry)')
@minValue(-1)
@maxValue(2147483647)
param analyticalStoreTTL int = -1

// ------------------
//    VARIABLES
// ------------------
var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'


// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawModule.outputs.id
    customMetricsOptedInType: 'WithDimensions'
  }
}

// 3. API Management
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'msi-${resourceSuffix}'
  location: resourceGroup().location
}
module apimModule '../../modules/apim/v2/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 4. AI Foundry
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
    name: 'foundryModule'
    params: {
      aiServicesConfig: aiServicesConfig
      modelsConfig: modelsConfig
      apimPrincipalId: apimModule.outputs.principalId
      foundryProjectName: foundryProjectName
    }
  }

// 5. APIM Inference API
module inferenceAPIModule '../../modules/apim/v2/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'workspace-${resourceSuffix}'
  dependsOn: [
    inferenceAPIModule
  ]
}
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    inferenceAPIModule
  ]
}

resource eventHubNamespaceResource 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: 'eventhub-${resourceSuffix}'
  location: eventHubLocation
  sku: {
    name: eventHubSKU
    tier: eventHubSKU
    capacity: eventHubSKUCapacity
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}

resource eventHubResource 'Microsoft.EventHub/namespaces/eventhubs@2021-01-01-preview' = {
  name: eventHubName
  parent: eventHubNamespaceResource
  properties: {
    messageRetentionInDays: 7
    partitionCount: 2
    status: 'Active'
  }
}

resource eventhubAuthRule 'Microsoft.EventHub/namespaces/AuthorizationRules@2022-01-01-preview' = {
  parent: eventHubNamespaceResource
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}

resource eventHubNamespaceResourceNWRulesets 'Microsoft.EventHub/namespaces/networkRuleSets@2022-01-01-preview' = {
  parent: eventHubNamespaceResource
  name: 'default'
  properties: {
    publicNetworkAccess: 'Enabled'
    defaultAction: 'Allow'
  }
}

resource eventHubConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2022-01-01-preview' = {
  parent: eventHubResource
  name: '$Default'
}

resource apimDiagnosticSettingsEventHub 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apimService
  name: 'apimDiagnosticSettingsEventHub'
  properties: {
    eventHubName: eventHubResource.name
    eventHubAuthorizationRuleId: eventhubAuthRule.id
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


var eventHubDataOwnerRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', 'f526a384-b230-433a-b45c-95f59c4a2dec')
resource eventHubsDataOwnerRoleAssignmentToStreamingJob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(streamingJobManagedIdentity.id, eventHubDataOwnerRoleDefinitionID)
  properties: {
    roleDefinitionId: eventHubDataOwnerRoleDefinitionID
    principalId: streamingJobManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource streamingJobManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${streamingJobsName}-${resourceSuffix}'
  location: resourceGroup().location
}

resource streamingJobsResource 'Microsoft.StreamAnalytics/streamingjobs@2021-10-01-preview' = {
  name: '${streamingJobsName}-${resourceSuffix}'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${streamingJobManagedIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: 'StandardV2'
    }
    outputStartMode: 'JobStartTime'
    eventsOutOfOrderPolicy: 'Adjust'
    outputErrorPolicy: 'Stop'
    eventsOutOfOrderMaxDelayInSeconds: 5
    compatibilityLevel: '1.2'
    inputs: [
      {
        name: 'eventhub'
        properties: {
          type: 'Stream'
          serialization: {
            type: 'Json'
            properties: {
              encoding: 'UTF8'
            }
          }
          datasource: {
            type: 'Microsoft.EventHub/EventHub'
            properties: {
              authenticationMode: 'Msi'
              eventHubName: eventHubResource.name
              serviceBusNamespace: eventHubNamespaceResource.name
            }
          }
        }
      }
    ]
    outputs: [
      {
        name: 'cosmosdb'
        properties: {
          datasource: {
            type: 'Microsoft.Storage/DocumentDB'
            properties: {
              accountId: cosmosDBAccountResource.name
              database: cosmosDBDatabaseResource.name
              collectionNamePattern: cosmosDBContainer.name
              authenticationMode: 'Msi'
              documentId: 'id'
              partitionKey: 'model'
            }
          }
        }
      }
    ]
    transformation: {
      name: 'transformation'
      properties: {
        query: 'WITH FlattenedRecords AS (SELECT record.ArrayValue.correlationId AS correlationId, record.ArrayValue.time AS time, record.ArrayValue.properties.ApimSubscriptionId AS ApimSubscriptionId, record.ArrayValue.properties.BackendId AS BackendId, record.ArrayValue.properties.modelName AS modelName, record.ArrayValue.properties.requestMessages AS requestMessages, record.ArrayValue.properties.responseMessages AS responseMessages, record.ArrayValue.properties.promptTokens AS promptTokens, record.ArrayValue.properties.completionTokens AS completionTokens, record.ArrayValue.properties.totalTokens AS totalTokens FROM [eventhub] CROSS APPLY GetArrayElements(records) AS record WHERE record.ArrayValue.correlationId IS NOT NULL), ConversationSummary AS (SELECT correlationId as id, STRING_AGG(modelName, "") AS model, STRING_AGG(ApimSubscriptionId, "") AS subscriptionId, STRING_AGG(BackendId, "") AS backendId, STRING_AGG(requestMessages, "") AS request, STRING_AGG(responseMessages, "") AS response, SUM(CAST(promptTokens AS BIGINT)) AS promptTokens, SUM(CAST(completionTokens AS BIGINT)) AS completionTokens, SUM(CAST(totalTokens AS BIGINT)) AS totalTokens, COUNT(*) AS messageCount, MIN(TRY_CAST(time AS DATETIME)) AS conversationStart FROM FlattenedRecords GROUP BY correlationId, TumblingWindow(minute, 5)) select * into [cosmosdb] from conversationSummary'
        streamingUnits: 3
      }
    }
  }
}

var cosmosDBLocations = [
  {
    locationName: resourceGroup().location
    failoverPriority: 0
    isZoneRedundant: false
  }
]
var throughput_Policy = {
  Manual: {
    throughput: manualProvisionedThroughput
  }
  Autoscale: {
    autoscaleSettings: {
      maxThroughput: autoscaleMaxThroughput
    }
  }
}

resource cosmosDBAccountResource 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: 'cosmosdb-${resourceSuffix}'
  location: resourceGroup().location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    databaseAccountOfferType: 'Standard'
    locations: cosmosDBLocations
    enableAnalyticalStorage: true
  }
}

var cosmosDBRoleDefinitionID = '00000000-0000-0000-0000-000000000002'
resource cosmosDBRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  parent: cosmosDBAccountResource
  name: guid(subscription().id, resourceGroup().id, cosmosDBAccountResource.name, cosmosDBRoleDefinitionID)
  properties:{
    principalId: streamingJobManagedIdentity.properties.principalId
    roleDefinitionId: '${cosmosDBAccountResource.id}/sqlRoleDefinitions/${cosmosDBRoleDefinitionID}'
    scope: cosmosDBAccountResource.id
  }
}

resource cosmosDBDatabaseResource 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  parent: cosmosDBAccountResource
  name: cosmosDBDatabaseName
  properties: {
    resource: {
      id: cosmosDBDatabaseName
    }
  }
}

resource cosmosDBContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = {
  parent: cosmosDBDatabaseResource
  name: cosmosDBContainerName
  properties: {
    resource: {
      id: cosmosDBContainerName
      partitionKey: {
        paths: [
          partitionKeyPath
        ]
        kind: 'Hash'
      }
      analyticalStorageTtl: analyticalStoreTTL
    }
    options: throughput_Policy[throughputPolicy]
  }
}


// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

output apimSubscriptions array = apimModule.outputs.apimSubscriptions


#disable-next-line outputs-should-not-contain-secrets
output cosmosDBConnectionString string = cosmosDBAccountResource.listConnectionStrings().connectionStrings[0].connectionString

