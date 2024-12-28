// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

// Required parameters
@description('Deployment 1 Name')
param openAIDeploymentName_1 string

@description('Deployment 2 Name')
param openAIDeploymentName_2 string

@description('Deployment 3 Name')
param openAIDeploymentName_3 string

@description('Model 1 Name')
param openAIModelName_1 string

@description('Model 2 Name')
param openAIModelName_2 string

@description('Model 3 Name')
param openAIModelName_3 string

@description('Model 1 Version')
param openAIModelVersion_1 string

@description('Model 2 Version')
param openAIModelVersion_2 string

@description('Model 3 Version')
param openAIModelVersion_3 string

param openAIAPIVersion string

// Optional parameters
param openAISku string = 'S0'
param openAIModelCapacity int = 20
param apimSku string = 'Basicv2'
param apimResourceLocation string = resourceGroup().location
param logAnalyticsLocation string = resourceGroup().location
param applicationInsightsLocation string = resourceGroup().location

@description('List of OpenAI resources to create for Pool 1. Add pairs of name and location.')
param openAIConfig_1 array = []

@description('List of OpenAI resources to create for Pool 2. Add pairs of name and location.')
param openAIConfig_2 array = []

@description('List of OpenAI resources to create for Pool 3. Add pairs of name and location.')
param openAIConfig_3 array = []

param apimResourceName string = 'apim'
param apimPublisherEmail string = 'noreply@microsoft.com'
param apimPublisherName string = 'Microsoft'
param openAIAPIName string = 'openai'
param openAIAPIPath string = 'openai'
param openAIAPIDisplayName string = 'OpenAI'
param openAIAPIDescription string = 'Azure OpenAI API inferencing API'
param openAISubscriptionName string = 'openai-subscription'
param openAISubscriptionDescription string = 'OpenAI Subscription'

param openAIBackendPoolName_1 string = 'openai-backend-pool-1'
param openAIBackendPoolName_2 string = 'openai-backend-pool-2'
param openAIBackendPoolName_3 string = 'openai-backend-pool-3'

param openAIBackendPoolDescription string = 'Load balancer for multiple OpenAI endpoints'
param logAnalyticsName string = 'workspace'
param applicationInsightsName string = 'insights'
param apimLoggerName string = 'apim-logger'
param apimLoggerDescription string  = 'APIM Logger for OpenAI API'
param workbookName string = 'OpenAIUsageAnalysis'
param workbookLocation string = resourceGroup().location
param workbookDisplayName string = 'OpenAI Usage Analysis'

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

// 1. Cognitive Services
resource cognitiveServices_1 'Microsoft.CognitiveServices/accounts@2021-10-01' = [for config in openAIConfig_1: if(length(openAIConfig_1) > 0) {
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

resource cognitiveServices_2 'Microsoft.CognitiveServices/accounts@2021-10-01' = [for config in openAIConfig_2: if(length(openAIConfig_2) > 0) {
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


resource cognitiveServices_3 'Microsoft.CognitiveServices/accounts@2021-10-01' = [for config in openAIConfig_3: if(length(openAIConfig_3) > 0) {
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

resource deployment_1 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for (config, i) in openAIConfig_1: if(length(openAIConfig_1) > 0) {
  name: openAIDeploymentName_1
  parent: cognitiveServices_1[i]
  properties: {
    model: {
      format: 'OpenAI'
      name: openAIModelName_1
      version: openAIModelVersion_1
    }
  }
  sku: {
    name: 'Standard'
    capacity: openAIModelCapacity
  }
}]

resource deployment_2 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for (config, i) in openAIConfig_2: if(length(openAIConfig_2) > 0) {
  name: openAIDeploymentName_2
  parent: cognitiveServices_2[i]
  properties: {
    model: {
      format: 'OpenAI'
      name: openAIModelName_2
      version: openAIModelVersion_2
    }
  }
  sku: {
    name: 'Standard'
    capacity: openAIModelCapacity
  }
}]

resource deployment_3 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for (config, i) in openAIConfig_3: if(length(openAIConfig_3) > 0) {
  name: openAIDeploymentName_3
  parent: cognitiveServices_3[i]
  properties: {
    model: {
      format: 'OpenAI'
      name: openAIModelName_3
      version: openAIModelVersion_3
    }
  }
  sku: {
    name: 'Standard'
    capacity: openAIModelCapacity
  }
}]

// 2. API Management
resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apiManagementName
  location: apimResourceLocation
  sku: {
    name: apimSku
    capacity: 1
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// 3. RBAC Assignment
resource roleAssignment_1 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig_1: if(length(openAIConfig_1) > 0) {
    scope: cognitiveServices_1[i]
    name: guid(subscription().id, resourceGroup().id, config.name, cognitiveServicesOpenAIUserRoleDefinitionID)
    properties: {
        roleDefinitionId: cognitiveServicesOpenAIUserRoleDefinitionID
        principalId: apimService.identity.principalId
        principalType: 'ServicePrincipal'
    }
}]

resource roleAssignment_2 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig_2: if(length(openAIConfig_2) > 0) {
  scope: cognitiveServices_2[i]
  name: guid(subscription().id, resourceGroup().id, config.name, cognitiveServicesOpenAIUserRoleDefinitionID)
  properties: {
      roleDefinitionId: cognitiveServicesOpenAIUserRoleDefinitionID
      principalId: apimService.identity.principalId
      principalType: 'ServicePrincipal'
  }
}]

resource roleAssignment_3 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig_3: if(length(openAIConfig_3) > 0) {
  scope: cognitiveServices_3[i]
  name: guid(subscription().id, resourceGroup().id, config.name, cognitiveServicesOpenAIUserRoleDefinitionID)
  properties: {
      roleDefinitionId: cognitiveServicesOpenAIUserRoleDefinitionID
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
    value: updatedPolicyXml
  }
}

// Optimize this
var circuitBreaker = {
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
          }, {
            min: 500
            max: 599
          }
        ]
      }
      name: 'myBreakerRule'
      tripDuration: 'PT1M'
      // acceptRetryAfter: true    // respects the Retry-After header
    }
  ]
}


resource backendOpenAI_1 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (config, i) in openAIConfig_1: if(length(openAIConfig_1) > 0) {
  name: config.name
  parent: apimService
  properties: {
    description: 'backend description'
    url: '${cognitiveServices_1[i].properties.endpoint}/openai'
    protocol: 'http'
    circuitBreaker: circuitBreaker
  }
}]

resource backendOpenAI_2 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (config, i) in openAIConfig_2: if(length(openAIConfig_2) > 0) {
  name: config.name
  parent: apimService
  properties: {
    description: 'backend description'
    url: '${cognitiveServices_2[i].properties.endpoint}/openai'
    protocol: 'http'
    circuitBreaker: circuitBreaker
  }
}]

resource backendOpenAI_3 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (config, i) in openAIConfig_3: if(length(openAIConfig_3) > 0) {
  name: config.name
  parent: apimService
  properties: {
    description: 'backend description'
    url: '${cognitiveServices_3[i].properties.endpoint}/openai'
    protocol: 'http'
    circuitBreaker: circuitBreaker
  }
}]

resource backendPoolOpenAI_1 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if(length(openAIConfig_1) > 1) {
  name: openAIBackendPoolName_1
  parent: apimService
  #disable-next-line BCP035
  properties: {
    description: openAIBackendPoolDescription
    type: 'Pool'
    pool: {
      services: [for (config, i) in openAIConfig_1: {
          id: '/backends/${backendOpenAI_1[i].name}'
        }
      ]
    }
  }
}

resource backendPoolOpenAI_2 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if(length(openAIConfig_2) > 1) {
  name: openAIBackendPoolName_2
  parent: apimService
  #disable-next-line BCP035
  properties: {
    description: openAIBackendPoolDescription
    type: 'Pool'
    pool: {
      services: [for (config, i) in openAIConfig_2: {
          id: '/backends/${backendOpenAI_2[i].name}'
        }
      ]
    }
  }
}

resource backendPoolOpenAI_3 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if(length(openAIConfig_3) > 1) {
  name: openAIBackendPoolName_3
  parent: apimService
  #disable-next-line BCP035
  properties: {
    description: openAIBackendPoolDescription
    type: 'Pool'
    pool: {
      services: [for (config, i) in openAIConfig_3: {
          id: '/backends/${backendOpenAI_3[i].name}'
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

// model-routing: additions BEGIN

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

resource diagnosticSettings_1 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (config, i) in openAIConfig_1: if(length(openAIConfig_1) > 0) {
  name: '${cognitiveServices_1[i].name}-diagnostics'
  scope: cognitiveServices_1[i]
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

resource diagnosticSettings_2 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (config, i) in openAIConfig_2: if(length(openAIConfig_2) > 0) {
  name: '${cognitiveServices_2[i].name}-diagnostics'
  scope: cognitiveServices_2[i]
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
  body: { bytes: 8192 }
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

// model-routing: additions END

output apimServiceId string = apimService.id

output apimResourceGatewayURL string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey
