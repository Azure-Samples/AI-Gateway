// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string
param openAIAPIVersion string = '2024-02-01'

// AI Foundry
@description('The AI Studio Hub Resource name')
param aiStudioHubName string
@description('The AI Studio Hub Resource location')
param aiStudioHubLocation string = resourceGroup().location

@description('The SKU name to use for the AI Studio Hub Resource')
param aiStudioSKUName string = 'Basic'
@description('The SKU tier to use for the AI Studio Hub Resource')
@allowed(['Basic', 'Free', 'Premium', 'Standard'])
param aiStudioSKUTier string = 'Basic'
@description('The name of the AI Studio Hub Project')
param aiStudioProjectName string

@description('The storage account ID to use for the AI Studio Hub Resource')
param storageAccountName string = 'storage'
@description('The storage account location')
param storageAccountLocation string = resourceGroup().location

@description('The key vault ID to use for the AI Studio Hub Resource')
param keyVaultName string = 'akv'
@description('The key vault location')
param keyVaultLocation string = resourceGroup().location

@description('The container registry ID to use for the AI Studio Hub Resource')
param containerRegistryName string = 'acr'
@description('The container registry location')
param containerRegistryLocation string = resourceGroup().location

@description('Embeddings Model Name')
param openAIEmbeddingsDeploymentName string = 'text-embedding-ada-002'

@description('Embeddings Model Name')
param openAIEmbeddingsModelName string = 'text-embedding-ada-002'

@description('Embeddings Model Version')
param openAIEmbeddingsModelVersion string = '2'

@description('AI Search service name')
@minLength(2)
@maxLength(60)
param searchServiceName string = 'search'

@description('AI Search service location')
param searchServiceLocation string = resourceGroup().location

@description('AI Search service SKU')
param searchServiceSku string = 'standard'

@description('Replicas distribute search workloads across the service. You need at least two replicas to support high availability of query workloads (not applicable to the free tier).')
@minValue(1)
@maxValue(12)
param searchServiceReplicaCount int = 1

@description('Partitions allow for scaling of document count as well as faster indexing by sharding your index over multiple search units.')
@allowed([
  1
  2
  3
  4
  6
  12
])
param searchServicePartitionCount int = 1

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var updatedPolicyXml = loadTextContent('policy-updated.xml')
var azureRoles = loadJsonContent('../../modules/azure-roles.json')
var cognitiveServicesOpenAIUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)
var roleDefinitionIDAISearchService = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.SearchServiceContributor)
var roleDefinitionIDAISearchIndex = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.SearchIndexDataContributor)

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

var lawId = lawModule.outputs.id

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    customMetricsOptedInType: 'WithDimensions'
    useWorkbook: false
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
    openAIEmbeddingsDeploymentName: openAIEmbeddingsDeploymentName
    openAIEmbeddingsModelName: openAIEmbeddingsModelName
    openAIEmbeddingsModelVersion: openAIEmbeddingsModelVersion
    lawId: lawId
  }
}

var extendedOpenAIConfig = openAIModule.outputs.extendedOpenAIConfig

// 4. API Management
module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    policyXml: updatedPolicyXml
    openAIConfig: extendedOpenAIConfig
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
  }
}

var apimPrincipalId = apimModule.outputs.principalId

// 5. RBAC Assignment
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (length(openAIConfig) > 0) {
  scope: resourceGroup()
  name: guid(subscription().id, resourceGroup().id, openAIConfig[0].name, cognitiveServicesOpenAIUserRoleDefinitionID)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAIUserRoleDefinitionID
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentAISearchService 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchService.name, roleDefinitionIDAISearchService)
  properties: {
    roleDefinitionId: roleDefinitionIDAISearchService
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentAISearchIndex 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(subscription().id, resourceGroup().id, searchService.name, roleDefinitionIDAISearchIndex)
  properties: {
    roleDefinitionId: roleDefinitionIDAISearchIndex
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// TODO: Move these resources into modules, if appropriate.

// prompt flow: additions BEGIN

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${keyVaultName}-${resourceSuffix}'
  location: keyVaultLocation
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    accessPolicies: []
  }
}

resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        objectId: hub.identity.principalId
        tenantId: subscription().tenantId
        permissions: { secrets: ['get', 'list'] }
      }
    ]
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: '${containerRegistryName}${resourceSuffix}'
  location: containerRegistryLocation
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
    metadataSearch: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
      softDeletePolicy: {
        retentionDays: 7
        status: 'disabled'
      }
    }
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${storageAccountName}${resourceSuffix}'
  location: storageAccountLocation
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowCrossTenantReplication: true
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    dnsEndpointType: 'Standard'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }

  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      cors: {
        corsRules: [
          {
            allowedOrigins: [
              'https://mlworkspace.azure.ai'
              'https://ml.azure.com'
              'https://*.ml.azure.com'
              'https://ai.azure.com'
              'https://*.ai.azure.com'
              'https://mlworkspacecanary.azure.ai'
              'https://mlworkspace.azureml-test.net'
            ]
            allowedMethods: [
              'GET'
              'HEAD'
              'POST'
              'PUT'
              'DELETE'
              'OPTIONS'
              'PATCH'
            ]
            maxAgeInSeconds: 1800
            exposedHeaders: [
              '*'
            ]
            allowedHeaders: [
              '*'
            ]
          }
        ]
      }
      deleteRetentionPolicy: {
        allowPermanentDelete: false
        enabled: false
      }
    }
    resource container 'containers' = {
      name: 'default'
      properties: {
        publicAccess: 'None'
      }
    }
  }

  resource fileServices 'fileServices' = {
    name: 'default'
    properties: {
      cors: {
        corsRules: [
          {
            allowedOrigins: [
              'https://mlworkspace.azure.ai'
              'https://ml.azure.com'
              'https://*.ml.azure.com'
              'https://ai.azure.com'
              'https://*.ai.azure.com'
              'https://mlworkspacecanary.azure.ai'
              'https://mlworkspace.azureml-test.net'
            ]
            allowedMethods: [
              'GET'
              'HEAD'
              'POST'
              'PUT'
              'DELETE'
              'OPTIONS'
              'PATCH'
            ]
            maxAgeInSeconds: 1800
            exposedHeaders: [
              '*'
            ]
            allowedHeaders: [
              '*'
            ]
          }
        ]
      }
      shareDeleteRetentionPolicy: {
        enabled: true
        days: 7
      }
    }
  }

  resource queueServices 'queueServices' = {
    name: 'default'
    properties: {}
    resource queue 'queues' = {
      name: 'default'
      properties: {
        metadata: {}
      }
    }
  }

  resource tableServices 'tableServices' = {
    name: 'default'
    properties: {}
  }
}

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: '${searchServiceName}-${resourceSuffix}'
  location: searchServiceLocation
  sku: {
    name: searchServiceSku
  }
  properties: {
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    replicaCount: searchServiceReplicaCount
    partitionCount: searchServicePartitionCount
  }
}

resource hub 'Microsoft.MachineLearningServices/workspaces@2024-01-01-preview' = {
  name: '${aiStudioHubName}-${resourceSuffix}'
  location: aiStudioHubLocation
  sku: {
    name: aiStudioSKUName
    tier: aiStudioSKUTier
  }
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: aiStudioHubName
    storageAccount: storage.id
    keyVault: keyVault.id
    applicationInsights: appInsightsId
    containerRegistry: containerRegistry.id
    hbiWorkspace: false
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    discoveryUrl: 'https://${aiStudioHubLocation}.api.azureml.ms/discovery'
  }

  resource openAiConnection 'connections@2024-04-01-preview' = {
    name: 'open_ai_connection'
    properties: {
      category: 'AzureOpenAI'
      authType: 'ApiKey'
      isSharedToAll: true
      target: apimModule.outputs.gatewayUrl
      enforceAccessToDefaultSecretStores: true
      metadata: {
        ApiVersion: '2024-02-01'
        ApiType: 'azure'
      }
      credentials: {
        key: apimModule.outputs.subscriptionPrimaryKey
      }
    }
  }

  resource AISearchConnection 'connections@2024-04-01-preview' = {
    name: 'ai_search_connection'
    properties: {
      category: 'CognitiveSearch'
      authType: 'ApiKey'
      isSharedToAll: true
      target: 'https://${searchServiceName}-${resourceSuffix}.search.windows.net'
      enforceAccessToDefaultSecretStores: true
      metadata: {
        ApiVersion: '2024-02-01'
        ApiType: 'azure'
      }
      credentials: {
        key: searchService.listAdminKeys().primaryKey
      }
    }
  }
}

resource project 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: '${aiStudioProjectName}-${resourceSuffix}'
  location: aiStudioHubLocation
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: aiStudioProjectName
    hbiWorkspace: false
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    discoveryUrl: 'https://${aiStudioHubLocation}.api.azureml.ms/discovery'
    hubResourceId: hub.id
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

output projectName string = project.name
output projectId string = project.id

var projectEndoint = replace(replace(project.properties.discoveryUrl, 'https://', ''), '/discovery', '')
output projectConnectionString string = '${projectEndoint};${subscription().subscriptionId};${resourceGroup().name};${project.name}'
