// ------------------
//    PARAMETERS
// ------------------

param apimSku string
param apimSubscriptionsConfig array = []
param inferenceAPIPath string = 'inference' // Path to the inference API in the APIM service

@secure()
param awsBedrockAccessKey string

@secure()
param awsBedrockSecretKey string

param awsBedrockServiceURL string

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

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: 'apim-${resourceSuffix}'
  dependsOn: [
    apimModule
  ]
}

resource accessKeyNV 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apimService
  name: 'accesskey'
  properties: {
    displayName: 'accesskey'
    secret: true
    value: awsBedrockAccessKey
  }
}

resource secretKeyNV 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apimService
  name: 'secretkey'
  properties: {
    displayName: 'secretkey'
    secret: true
    value: awsBedrockSecretKey
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'inference-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'Inferencing API for AWS BedRock'
    displayName: 'Inferencing API'
    format: 'openapi+json'
    path: inferenceAPIPath
    serviceUrl: awsBedrockServiceURL
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: string(loadJsonContent('../../modules/apim/v2/specs/PassThrough.json'))
  }
}
// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: loadTextContent('policy.xml')
  }
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: api
  name: 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: apimModule.outputs.loggerId
    sampling: {
      samplingType: 'fixed'
      percentage: json('100')
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    largeLanguageModel: {
      logs: 'enabled'
      requests: {
        messages: 'all'
        maxSizeInBytes: 262144
      }
      responses: {
        messages: 'all'
        maxSizeInBytes: 262144
      }
    }
  }
} 


resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'workspace-${resourceSuffix}'
  dependsOn: [
    apimModule
  ]
}

resource modelUsageFunction 'Microsoft.OperationalInsights/workspaces/savedSearches@2025-02-01' = {
  parent: logAnalytics
  name: '${guid(subscription().subscriptionId, resourceGroup().id)}_model_usage'
  properties: {
    category: 'llm'
    displayName: 'model_usage'
    version: 2
    functionAlias: 'model_usage'
    query: 'let llmHeaderLogs = ApiManagementGatewayLlmLog \r\n| where DeploymentName != \'\'; \r\nlet llmLogsWithSubscriptionId = llmHeaderLogs \r\n| join kind=leftouter ApiManagementGatewayLogs on CorrelationId \r\n| project \r\n    SubscriptionId = ApimSubscriptionId, DeploymentName, PromptTokens, CompletionTokens, TotalTokens; \r\nllmLogsWithSubscriptionId \r\n| summarize \r\n    SumPromptTokens      = sum(PromptTokens), \r\n    SumCompletionTokens      = sum(CompletionTokens), \r\n    SumTotalTokens      = sum(TotalTokens) \r\n  by SubscriptionId, DeploymentName'
  }
}

resource promptsAndCompletionsFunction 'Microsoft.OperationalInsights/workspaces/savedSearches@2025-02-01' = {
  parent: logAnalytics
  name: '${guid(subscription().subscriptionId, resourceGroup().id)}_prompts_and_completions'
  properties: {
    category: 'llm'
    displayName: 'prompts_and_completions'
    version: 2
    functionAlias: 'prompts_and_completions'
    query: 'ApiManagementGatewayLlmLog\r\n| extend RequestArray = parse_json(RequestMessages)\r\n| extend ResponseArray = parse_json(ResponseMessages)\r\n| mv-expand RequestArray\r\n| mv-expand ResponseArray\r\n| project\r\n    CorrelationId, \r\n    RequestContent = tostring(RequestArray.content), \r\n    ResponseContent = tostring(ResponseArray.content)\r\n| summarize \r\n    Input = strcat_array(make_list(RequestContent), " . "), \r\n    Output = strcat_array(make_list(ResponseContent), " . ")\r\n    by CorrelationId\r\n| where isnotempty(Input) and isnotempty(Output)\r\n'
  }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

output apimSubscriptions array = apimModule.outputs.apimSubscriptions
