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

// built-in logging: additions END

// prompt flow: additions BEGIN

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

@description('The name of the Container App image')
param flowName string

@description('The prompt flow API Name')
param promptFlowAPIName string = flowName
@description('The prompt flow API Description')
param promptFlowAPIDescription string = 'Prompt flow API'
@description('The prompt flow API Display Name')
param promptFlowDisplayName string = flowName
@description('The prompt flow API Path')
param promptFlowAPIPath string = flowName

@description('The name of the Container App Environment')
param containerAppEnvName string
@description('The location of the Container App Environment')
param containerAppEnvLocation string = resourceGroup().location
@description('The name of the Container App')
param containerAppName string


// prompt flow: additions END

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
    type: 'SystemAssigned'
  } 
}

var roleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
    scope: cognitiveServices[i]
    name: guid(subscription().id, resourceGroup().id, config.name, roleDefinitionID)
    properties: {
        roleDefinitionId: roleDefinitionID
        principalId: apimService.identity.principalId
        principalType: 'ServicePrincipal'
    }
}]

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
    scope: '/apis'
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
    CustomMetricsOptedInType: 'WithDimensions'
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

output applicationInsightsAppId string = applicationInsights.properties.AppId

output logAnalyticsWorkspaceId string = logAnalytics.properties.customerId

// buult-in logging: additions END

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
    accessPolicies: [ {
        objectId: hub.identity.principalId
        tenantId: subscription().tenantId
        permissions: { secrets: [ 'get', 'list' ] }
      } ]
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
    policies:{
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
    properties: {

    }
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
    applicationInsights: applicationInsights.id
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
      target: apimService.properties.gatewayUrl
      enforceAccessToDefaultSecretStores: true
      metadata: {
        ApiVersion: '2024-02-01'
        ApiType: 'azure'
      }
      credentials: {
        key: apimSubscription.listSecrets().primaryKey
      }
    }
  }  
}


resource project 'Microsoft.MachineLearningServices/workspaces@2024-01-01-preview' = {
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

resource promptFlowAPI 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: promptFlowAPIName
  parent: apimService
  properties: {
    apiType: 'http'
    description: promptFlowAPIDescription
    displayName: promptFlowDisplayName
    format: 'openapi+json'
    path: promptFlowAPIPath
    serviceUrl: 'https://${containerApp.properties.configuration.ingress.fqdn}/'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: loadJsonContent('basic-chat/openapi.json')
  }
}

resource promptFlowAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if (!empty(apimLogger.name)) {
  name: 'applicationinsights'
  parent: promptFlowAPI
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

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: '${containerAppEnvName}-${resourceSuffix}'
  location: containerAppEnvLocation
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}


resource containerAppUAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${containerAppName}-mi-${resourceSuffix}'
  location: containerAppEnvLocation
}
var acrPullRole = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
@description('This allows the managed identity of the container app to access the registry, note scope is applied to the wider ResourceGroup not the ACR')
resource containerAppUAIRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, containerAppUAI.id, acrPullRole)
  properties: {
    roleDefinitionId: acrPullRole
    principalId: containerAppUAI.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource containerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: '${containerAppName}-${resourceSuffix}'
  location: containerAppEnvLocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppUAI.id}': {}
    }
  }  
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          name: '${containerAppName}-${resourceSuffix}'
          image: 'docker.io/jfxs/hello-world:latest'
          env: [
            {
              name: 'OPEN_AI_CONNECTION_API_KEY'
              value: apimSubscription.listSecrets().primaryKey
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: applicationInsights.properties.ConnectionString
            }
          ]          
          resources: {
            cpu: json('.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }    
  }
}

output containerAppResourceName string = containerApp.name
output containerAppFQDN string = containerApp.properties.configuration.ingress.fqdn


output projectName string = project.name
output projectId string = project.id

// prompt flow: additions END


output apimServiceId string = apimService.id

output apimResourceGatewayURL string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey
