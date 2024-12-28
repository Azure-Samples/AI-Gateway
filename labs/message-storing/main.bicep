// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

// Required parameters
param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string
param openAIAPIVersion string
// Optional parameters
param apimResourceName string = 'apim'
param apimPublisherEmail string = 'noreply@microsoft.com'
param apimPublisherName string = 'Microsoft'
param openAIAPIName string = 'openai'
param openAIAPIPath string = 'openai'
param openAIAPIDisplayName string = 'OpenAI'
param openAIAPIDescription string = 'Azure OpenAI API inferencing API'
param openAISubscriptionName string = 'openai-subscription'
param openAISubscriptionDescription string = 'OpenAI Subscription'
param openAIBackendPoolName string = 'openai-backend-pool'
param openAIBackendPoolDescription string = 'Load balancer for multiple OpenAI endpoints'
param logAnalyticsName string = 'workspace'
param applicationInsightsName string = 'insights'
param apimLoggerName string = 'apim-logger'
param apimLoggerDescription string  = 'APIM Logger for OpenAI API'
param workbookName string = 'OpenAIUsageAnalysis'
param workbookDisplayName string = 'OpenAI Usage Analysis'

@description('Event Hub namespace name')
param eventHubNamespaceName string

@description('Event Hub namespace location')
param eventHubLocation string = resourceGroup().location

@description('Event Hub SKU')
param eventHubSKU string = 'Standard'

@description('Event Hub SKU capacity')
param eventHubSKUCapacity int = 1

@description('Event Hub name')
param eventHubName string

@description('APIM logger name for Event Hub')
param eventHubLoggerName string

@description('Streaming Jobs name')
param streamingJobsName string

@description('Streaming Jobs location')
param streamingJobsLocation string = resourceGroup().location

@description('Azure Cosmos DB account name')
param cosmosDBAccountName string

@description('Location for the Azure Cosmos DB account.')
param cosmosDBLocation string = resourceGroup().location

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
// message storing: additions END

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = '${apimResourceName}-${resourceSuffix}'
var updatedPolicyXml = loadTextContent('policy-updated.xml')
var openAIAPISpecURL = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/${openAIAPIVersion}/inference.json'
var azureRoles = loadJsonContent('../../modules/azure-roles.json')
var cognitiveServicesOpenAIUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
  params: {
    logAnalyticsName: logAnalyticsName
  }
}

var lawId = lawModule.outputs.id

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    applicationInsightsName: applicationInsightsName
    workbookName: workbookName
    workbookDisplayName: workbookDisplayName
    workbookJson: loadTextContent('openai-usage-analysis-workbook.json')
    lawId: lawId
  }
}

var appInsightsId = appInsightsModule.outputs.id
var appInsightsInstrumentationKey = appInsightsModule.outputs.instrumentationKey

// 3. Cognitive Services
module openAIModule '../../modules/cognitive-services/v1/openai.bicep' = {
  name: 'openAIModule'
  params: {
    openAIConfig: openAIConfig
    openAIDeploymentName: openAIDeploymentName
    openAIModelName: openAIModelName
    openAIModelVersion: openAIModelVersion
    lawId: lawId
  }
}

var extendedOpenAIConfig = openAIModule.outputs.extendedOpenAIConfig

// 4. User-Assigned Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${apimResourceName}-${resourceSuffix}'
  location: resourceGroup().location
}

// 5. API Management
module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    apiManagementName: apiManagementName
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    policyXml: updatedPolicyXml
    openAIConfig: extendedOpenAIConfig
    openAIAPIDescription:openAIAPIDescription
    openAIAPIDisplayName: openAIAPIDisplayName
    openAIAPIName: openAIAPIName
    openAIAPIPath: openAIAPIPath
    openAIAPISpecURL: openAIAPISpecURL
    openAIBackendPoolDescription: openAIBackendPoolDescription
    openAIBackendPoolName: openAIBackendPoolName
    openAISubscriptionDescription: openAISubscriptionDescription
    openAISubscriptionName: openAISubscriptionName
    apimLoggerName: apimLoggerName
    apimLoggerDescription: apimLoggerDescription
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
    apimManagedIdentityType: 'UserAssigned'
    apimUserAssignedManagedIdentityId: managedIdentity.id
  }
}

var apimPrincipalId = apimModule.outputs.principalId

// We presume the APIM resource has been created as part of this bicep flow.
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
}

resource managedIdentityNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  name: 'managed-identity-clientid'
  parent: apim
  properties: {
    displayName: 'managed-identity-clientid'
    secret: true
    value: managedIdentity.properties.clientId
  }
}

// 6. RBAC Assignment
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(length(openAIConfig) > 0) {
  scope: resourceGroup()
  name: guid(subscription().id, resourceGroup().id, openAIConfig[0].name, cognitiveServicesOpenAIUserRoleDefinitionID)
    properties: {
        roleDefinitionId: cognitiveServicesOpenAIUserRoleDefinitionID
        principalId: apimPrincipalId
        principalType: 'ServicePrincipal'
    }
}



// message storing: additions BEGIN
resource eventHubNamespaceResource 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: '${eventHubNamespaceName}-${resourceSuffix}'
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

resource eventHubLogger 'Microsoft.ApiManagement/service/loggers@2022-08-01' = {
  name: eventHubLoggerName
  parent: apim
  properties: {
    loggerType: 'azureEventHub'
    description: 'Log messages to Event Hub'
    credentials: {
      name: eventHubResource.name
      endpointAddress: replace(eventHubNamespaceResource.properties.serviceBusEndpoint, 'https://', '')
      identityClientId: managedIdentity.properties.clientId
    }
  }
}

var eventHubDataSenderRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.AzureEventHubsDataSender)
resource eventHubsDataSenderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: eventHubNamespaceResource
  name: guid(subscription().id, resourceGroup().id, eventHubNamespaceResource.name, eventHubDataSenderRoleDefinitionID)
  properties: {
    roleDefinitionId: eventHubDataSenderRoleDefinitionID
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

var eventHubDataOwnerRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.AzureEventHubsDataOwner)
resource eventHubsDataOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
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
  location: streamingJobsLocation
}

resource streamingJobsResource 'Microsoft.StreamAnalytics/streamingjobs@2021-10-01-preview' = {
  name: '${streamingJobsName}-${resourceSuffix}'
  location: streamingJobsLocation
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
        query: 'SELECT * INTO [cosmosdb] FROM [eventhub]'
        streamingUnits: 3
      }
    }
  }
}

var cosmosDBLocations = [
  {
    locationName: cosmosDBLocation
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
  name: '${cosmosDBAccountName}-${resourceSuffix}'
  location: cosmosDBLocation
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

output applicationInsightsAppId string = appInsightsModule.outputs.appId
output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = apimModule.outputs.subscriptionPrimaryKey
#disable-next-line outputs-should-not-contain-secrets
output cosmosDBConnectionString string = cosmosDBAccountResource.listConnectionStrings().connectionStrings[0].connectionString
