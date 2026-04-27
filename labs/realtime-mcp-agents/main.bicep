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
param spotifyAPIPath string = 'spotify_mcp'
param weatherAPIPath string = 'weather'

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

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'acr${resourceSuffix}'
  location: resourceGroup().location
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

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: 'aca-env-${resourceSuffix}'
  location: resourceGroup().location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: lawModule.outputs.customerId
        sharedKey: lawModule.outputs.primarySharedKey
      }
    }
  }
}

resource containerAppUAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'aca-mi-${resourceSuffix}'
  location: resourceGroup().location
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

resource spotifyMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-spotify-${resourceSuffix}'
  location: resourceGroup().location
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
      registries: [
        {
          identity: containerAppUAI.id
          server: containerRegistry.properties.loginServer
        }
      ]      
    }
    template: {
      containers: [
        {
          name: 'aca-${resourceSuffix}'
          image: 'docker.io/jfxs/hello-world:latest'
          env: [
            {
              name: 'APIM_GATEWAY_URL'
              value: '${apimService.properties.gatewayUrl}/${spotifyAPIPath}'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: containerAppUAI.properties.clientId
            }                         
            {
              name: 'AZURE_TENANT_ID'
              value: subscription().tenantId
            }                         
            {
              name: 'SUBSCRIPTION_ID'
              value: subscription().subscriptionId
            }                         
            {
              name: 'RESOURCE_GROUP_NAME'
              value: resourceGroup().name
            }                         
            {
              name: 'APIM_SERVICE_NAME'
              value: apimService.name
            }                         
            {
              name: 'POST_LOGIN_REDIRECT_URL'
              value: 'https://open.spotify.com/'
            }                         
            {
              name: 'APIM_IDENTITY_OBJECT_ID'
              value: apimService.identity.principalId
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

resource weatherMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-weather-${resourceSuffix}'
  location: resourceGroup().location
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
      registries: [
        {
          identity: containerAppUAI.id
          server: containerRegistry.properties.loginServer
        }
      ]      
    }
    template: {
      containers: [
        {
          name: 'aca-${resourceSuffix}'
          image: 'docker.io/jfxs/hello-world:latest'
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

module spotifyAPIModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'spotifyAPIModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: spotifyAPIPath
    MCPServiceURL: 'https://${spotifyMCPServerContainerApp.properties.configuration.ingress.fqdn}/${spotifyAPIPath}'
  }
}

module weatherAPIModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'weatherAPIModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: weatherAPIPath
    MCPServiceURL: 'https://${weatherMCPServerContainerApp.properties.configuration.ingress.fqdn}/${weatherAPIPath}'
  }
}

var apimContributorRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '312a565d-c81f-4fd8-895a-4e21e48d571c')
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  {
    scope: apimService
    name: guid(subscription().id, resourceGroup().id, apimContributorRoleDefinitionID)
    properties: {
        roleDefinitionId: apimContributorRoleDefinitionID
        principalId: containerAppUAI.properties.principalId
        principalType: 'ServicePrincipal'
    }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimServiceName string = apimModule.outputs.name

output apimSubscriptions array = apimModule.outputs.apimSubscriptions

output containerRegistryName string = containerRegistry.name

output spotifyMCPServerContainerAppResourceName string = spotifyMCPServerContainerApp.name
output spotifyMCPServerContainerAppFQDN string = spotifyMCPServerContainerApp.properties.configuration.ingress.fqdn

output weatherMCPServerContainerAppResourceName string = weatherMCPServerContainerApp.name
output weatherMCPServerContainerAppFQDN string = weatherMCPServerContainerApp.properties.configuration.ingress.fqdn

