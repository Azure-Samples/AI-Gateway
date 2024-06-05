@description('List of Mock webapp names used to simulate OpenAI behavior.')
param mockWebApps array = []

@description('The name of the OpenAI mock backend pool')
param mockBackendPoolName string = 'openai-backend-pool'

@description('The description of the OpenAI mock backend pool')
param mockBackendPoolDescription string = 'Load balancer for multiple OpenAI Mocking endpoints'

@description('List of OpenAI resources to create. Add pairs of name and location.')
param openAIConfig array = []

@description('Deployment Name')
param openAIDeploymentName string

@description('Azure OpenAI Sku')
@allowed([
  'S0'
])
param openAISku string = 'S0'

@description('Model Name')
param openAIModelName string

@description('Model Version')
param openAIModelVersion string

@description('Model Capacity')
param openAIModelCapacity int = 20

@description('The name of the API Management resource')
param apimResourceName string

@description('Location for the APIM resource')
param apimResourceLocation string = resourceGroup().location

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
param apimSku string = 'Consumption'

@description('The instance size of this API Management service.')
@allowed([
  0
  1
  2
])
param apimSkuCount int = 1

@description('The email address of the owner of the service')
param apimPublisherEmail string = 'noreply@microsoft.com'

@description('The name of the owner of the service')
param apimPublisherName string = 'Microsoft'

@description('The name of the APIM API for OpenAI API')
param openAIAPIName string = 'openai'

@description('The relative path of the APIM API for OpenAI API')
param openAIAPIPath string = 'openai'

@description('The display name of the APIM API for OpenAI API')
param openAIAPIDisplayName string = 'OpenAI'

@description('The description of the APIM API for OpenAI API')
param openAIAPIDescription string = 'Azure OpenAI API inferencing API'

@description('Full URL for the OpenAI API spec')
param openAIAPISpecURL string = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json'

@description('The name of the APIM Subscription for OpenAI API')
param openAISubscriptionName string = 'openai-subscription'

@description('The description of the APIM Subscription for OpenAI API')
param openAISubscriptionDescription string = 'OpenAI Subscription'

@description('The name of the OpenAI backend pool')
param openAIBackendPoolName string = 'openai-backend-pool'

@description('The description of the OpenAI backend pool')
param openAIBackendPoolDescription string = 'Load balancer for multiple OpenAI endpoints'

// buult-in logging: additions BEGIN

@description('Name of the Log Analytics resource')
param logAnalyticsName string = 'workspace'

@description('Location of the Log Analytics resource')
param logAnalyticsLocation string = resourceGroup().location

@description('Name of the Application Insights resource')
param applicationInsightsName string = 'insights'

@description('Location of the Application Insights resource')
param applicationInsightsLocation string = resourceGroup().location

@description('Name of the APIM Logger')
param apimLoggerName string = 'apim-logger'

@description('Description of the APIM Logger')
param apimLoggerDescription string  = 'APIM Logger for OpenAI API'

@description('Number of bytes to log for API diagnostics')
param apiDiagnosticsLogBytes int = 8192

@description(' Name for the Workbook')
param workbookName string = 'OpenAIUsageAnalysis'

@description('Location for the Workbook')
param workbookLocation string = resourceGroup().location

@description('Display Name for the Workbook')
param workbookDisplayName string = 'OpenAI Usage Analysis'

// buult-in logging: additions END

// message storing: additions BEGIN

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

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

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

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${apimResourceName}-${resourceSuffix}'
  location: apimResourceLocation
}

resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: '${apimResourceName}-${resourceSuffix}'
  location: apimResourceLocation
  sku: {
    name: apimSku
    capacity: (apimSku == 'Consumption') ? 0 : ((apimSku == 'Developer') ? 1 : apimSkuCount)
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
}

var roleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
    scope: cognitiveServices[i]
    name: guid(subscription().id, resourceGroup().id, config.name, roleDefinitionID)
    properties: {
        roleDefinitionId: roleDefinitionID
        principalId: managedIdentity.properties.principalId
        principalType: 'ServicePrincipal'
    }
}]

resource managedIdentityNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: 'managed-identity-clientid'
  parent: apimService
  properties: {
    displayName: 'managed-identity-clientid'
    secret: true
    value: managedIdentity.properties.clientId
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
    name: openAIAPIName
    parent: apimService
    properties: {
      apiType: 'http'
      description: openAIAPIDescription
      displayName: openAIAPIDisplayName
      format: 'openapi-link'
      path: openAIAPIPath
      protocols: [
        'https'
      ]
      subscriptionKeyParameterNames: {
        header: 'api-key'
        query: 'api-key'
      }
      subscriptionRequired: true
      type: 'http'
      value: openAIAPISpecURL
    }
  }

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: loadTextContent('policy.xml')
  }
}

resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: config.name
  parent: apimService
  properties: {
    description: 'backend description'
    url: '${cognitiveServices[i].properties.endpoint}/openai'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 3
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT5M'
            statusCodeRanges: [
              {
                min: 429
                max: 429
              }
            ]
          }
          name: 'openAIBreakerRule'
          tripDuration: 'PT1M'
        }
      ]
    }    
  }
}]

resource backendMock 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (mock, i) in mockWebApps: if(length(openAIConfig) == 0 && length(mockWebApps) > 0) {
  name: mock.name
  parent: apimService
  properties: {
    description: 'backend description'
    url: '${mock.endpoint}/openai'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 3
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT5M'
            statusCodeRanges: [
              {
                min: 429
                max: 429
              }
            ]
          }
          name: 'mockBreakerRule'
          tripDuration: 'PT1M'
        }
      ]
    }    
  }
}]

resource backendPoolOpenAI 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if(length(openAIConfig) > 1) {
  name: openAIBackendPoolName
  parent: apimService
  properties: {
    description: openAIBackendPoolDescription
    type: 'Pool'
//    protocol: 'http'  // the protocol is not needed in the Pool type
//    url: '${cognitiveServices[0].properties.endpoint}/openai'   // the url is not needed in the Pool type
    pool: {
      services: [for (config, i) in openAIConfig: {
          id: '/backends/${backendOpenAI[i].name}'
        }
      ]
    }
  }
}

resource backendPoolMock 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if(length(openAIConfig) == 0 && length(mockWebApps) > 1) {
  name: mockBackendPoolName
  parent: apimService
  properties: {
    description: mockBackendPoolDescription
    type: 'Pool'
//    protocol: 'http'  // the protocol is not needed in the Pool type
//    url: '${mockWebApps[0].endpoint}/openai'   // the url is not needed in the Pool type
    pool: {
      services: [for (webApp, i) in mockWebApps: {
          id: '/backends/${backendMock[i].name}'
        }
      ]
    }
  }
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  name: openAISubscriptionName
  parent: apimService
  properties: {
    allowTracing: true
    displayName: openAISubscriptionDescription
    scope: '/apis/${api.id}'
    state: 'active'
  }
}

// buult-in logging: additions BEGIN

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: '${logAnalyticsName}-${resourceSuffix}'
  location: logAnalyticsLocation
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

/*
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: '${cognitiveServices[i].name}-diagnostics'
  scope: cognitiveServices[i]
  properties: {
    workspaceId: logAnalytics.id
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true 
      }
    ]
  }
}]
*/

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${applicationInsightsName}-${resourceSuffix}'
  location: applicationInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: apimLoggerName
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: apimLoggerDescription
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

var logSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens' , 'x-ratelimit-remaining-requests' ]
  body: { bytes: apiDiagnosticsLogBytes }
}
resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if (!empty(apimLogger.name)) {
  name: 'applicationinsights'
  parent: api
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: apimLogger.id
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, workbookName)
  location: workbookLocation
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: loadTextContent('openai-usage-analysis-workbook.json')
    sourceId: applicationInsights.id
    category: 'OpenAI'
  }
}
output applicationInsightsAppId string = applicationInsights.properties.AppId

output logAnalyticsWorkspaceId string = logAnalytics.properties.customerId

// buult-in logging: additions END

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
  parent: apimService
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

var eventHubDataSenderRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975')
resource eventHubsDataSenderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: eventHubNamespaceResource
  name: guid(subscription().id, resourceGroup().id, eventHubNamespaceResource.name, eventHubDataSenderRoleDefinitionID)
  properties: {
    roleDefinitionId: eventHubDataSenderRoleDefinitionID
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

var eventHubDataOwnerRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', 'f526a384-b230-433a-b45c-95f59c4a2dec')
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

// message storing: additions END

output apimServiceId string = apimService.id

output apimResourceGatewayURL string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey

#disable-next-line outputs-should-not-contain-secrets
output cosmosDBConnectionString string = cosmosDBAccountResource.listConnectionStrings().connectionStrings[0].connectionString
