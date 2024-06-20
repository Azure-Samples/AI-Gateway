@description('List of OpenAI resources to create for Pool 1. Add pairs of name and location.')
param openAIConfig_1 array = []

@description('List of OpenAI resources to create for Pool 2. Add pairs of name and location.')
param openAIConfig_2 array = []

@description('Deployment 1 Name')
param openAIDeploymentName_1 string

@description('Deployment 2 Name')
param openAIDeploymentName_2 string

@description('Azure OpenAI Sku')
@allowed([
  'S0'
])
param openAISku string = 'S0'

@description('Model 1 Name')
param openAIModelName_1 string

@description('Model 1 Version')
param openAIModelVersion_1 string

@description('Model 2 Name')
param openAIModelName_2 string

@description('Model 2 Version')
param openAIModelVersion_2 string

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
param openAIBackendPoolName_1 string = 'openai-backend-pool-1'
param openAIBackendPoolName_2 string = 'openai-backend-pool-2'

@description('The description of the OpenAI backend pool')
param openAIBackendPoolDescription string = 'Load balancer for multiple OpenAI endpoints'

// model-routing: additions BEGIN

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

// model-routing: additions END



var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

//var openAIConfigs = union(openAIConfig_1, openAIConfig_2)

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

// Optimize this
resource deployment_1 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01'  =  [for (config, i) in openAIConfig_1: if(length(openAIConfig_1) > 0) {
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

resource deployment_2 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01'  =  [for (config, i) in openAIConfig_2: if(length(openAIConfig_2) > 0) {
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
resource roleAssignment_1 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig_1: if(length(openAIConfig_1) > 0) {
    scope: cognitiveServices_1[i]
    name: guid(subscription().id, resourceGroup().id, config.name, roleDefinitionID)
    properties: {
        roleDefinitionId: roleDefinitionID
        principalId: apimService.identity.principalId
        principalType: 'ServicePrincipal'
    }
}]

resource roleAssignment_2 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig_2: if(length(openAIConfig_2) > 0) {
  scope: cognitiveServices_2[i]
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

// Optimize this
resource backendOpenAI_1 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (config, i) in openAIConfig_1: if(length(openAIConfig_1) > 0) {
  name: config.name
  parent: apimService
  properties: {
    description: 'backend description'
    url: '${cognitiveServices_1[i].properties.endpoint}/openai'
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

resource backendOpenAI_2 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (config, i) in openAIConfig_2: if(length(openAIConfig_2) > 0) {
  name: config.name
  parent: apimService
  properties: {
    description: 'backend description'
    url: '${cognitiveServices_2[i].properties.endpoint}/openai'
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

resource backendPoolOpenAI_1 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if(length(openAIConfig_1) > 1) {
  name: openAIBackendPoolName_1
  parent: apimService
  #disable-next-line BCP035
  properties: {
    description: openAIBackendPoolDescription
    type: 'Pool'
    //protocol: 'http'                                              // the protocol is not supported in the Pool type
    //url: '${cognitiveServices_1[0].properties.endpoint}/openai'   // the url is not supported in the Pool type
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
    //protocol: 'http'                                              // the protocol is not supported in the Pool type
    //url: '${cognitiveServices_2[0].properties.endpoint}/openai'   // the url is not supported in the Pool type
    pool: {
      services: [for (config, i) in openAIConfig_2: {
          id: '/backends/${backendOpenAI_2[i].name}'
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

// model-routing: additions END

output apimServiceId string = apimService.id

output apimResourceGatewayURL string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey


