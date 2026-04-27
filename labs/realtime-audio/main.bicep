// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
param inferenceAPIPath string = 'inference' // Path to the inference API in the APIM service
param inferenceAPIType string = 'AzureOpenAI'
param foundryProjectName string = 'default'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

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

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: 'apim-${resourceSuffix}'
  dependsOn: [
    foundryModule
  ]
}

// 5. APIM OpenAI-RT Websocket API
// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'realtime-audio'
  parent: apimService
  properties: {
    apiType: 'websocket'
    description: 'Inference API for Azure OpenAI Realtime'
    displayName: 'InferenceAPI'
    path: '${inferenceAPIPath}/openai/realtime'
    serviceUrl: '${replace(foundryModule.outputs.extendedAIServicesConfig[0].endpoint, 'https:', 'wss:')}openai/realtime'
    type: inferenceAPIType
    protocols: [
      'wss'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
  }
}

resource rtOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  name: 'onHandshake'
  parent: api
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource rtPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: rtOperation
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
    foundryModule
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

