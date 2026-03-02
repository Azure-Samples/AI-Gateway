// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string = 'Basicv2'
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference' // Path to the inference API in APIM
param foundryProjectName string = 'default'

param weatherMCPPath string = 'weather'

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

// 3. API Management (Basicv2)
module apimModule '../../modules/apim/v3/apim.bicep' = {
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
// aiServicesConfig[0] = foundry-inference (swedencentral) with gpt-4.1 model deployment
// aiServicesConfig[1] = foundry-agent (eastus2) for hosted agent - no direct model deployment
// modelsConfig uses 'aiservice' field to target only foundry-inference for model deployment
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
  name: 'foundryModule'
  params: {
    aiServicesConfig: aiServicesConfig
    modelsConfig: modelsConfig
    apimPrincipalId: apimModule.outputs.principalId
    foundryProjectName: foundryProjectName
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 5. APIM Inference API (backed by foundry-inference)
module inferenceAPIModule '../../modules/apim/v3/inference-api.bicep' = {
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

// -- Existing resource references (after modules are deployed) --

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    inferenceAPIModule
  ]
}

// APIM subscription for the hosted agent ACA to call inference
resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'hosted-agent-subscription'
  parent: apimService
  properties: {
    allowTracing: true
    displayName: 'Hosted Agent Subscription'
    scope: '/apis'
    state: 'active'
  }
}

// AI Foundry account for the agent project (aiServicesConfig[1])
resource aiFoundryAgent 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: '${aiServicesConfig[1].name}-${resourceSuffix}'
  dependsOn: [
    foundryModule
  ]
}

// 6. Container Registry (for building and storing the hosted agent image)
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'acr${resourceSuffix}'
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// 7. Container App Environment
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

// 8. User Assigned Identity for Container Apps
resource containerAppUAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'aca-mi-${resourceSuffix}'
  location: resourceGroup().location
}

var acrPullRoleId = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
resource containerAppUAIAcrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, containerAppUAI.id, acrPullRoleId)
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: containerAppUAI.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the hosted agent UAI Cognitive Services User on the agent foundry account
var cognitiveServicesUserRoleId = resourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
resource containerAppUAIFoundryRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, containerAppUAI.id, cognitiveServicesUserRoleId)
  scope: aiFoundryAgent
  properties: {
    roleDefinitionId: cognitiveServicesUserRoleId
    principalId: containerAppUAI.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// 9. Weather MCP Server Container App (starts with placeholder image; update after building src/weather-mcp)
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
          name: 'weather-mcp-server'
          // Placeholder image – replaced when running the "Build & Deploy" notebook cells
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

// 10. APIM Streamable MCP API for the Weather MCP Server
module weatherMCPModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'weatherMCPModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: weatherMCPPath
    MCPServiceURL: 'https://${weatherMCPServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

// 11. Weather MCP connection on the agent foundry project
resource weatherMCPConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'WeatherMCP'
  parent: aiFoundryAgent
  properties: {
    category: 'CustomKeys'
    authType: 'CustomKeys'
    target: '${apimService.properties.gatewayUrl}/${weatherMCPPath}/mcp'
    isSharedToAll: true
    credentials: {
      keys: {
        'api-key': apimSubscription.listSecrets().primaryKey
      }
    }
    metadata: {
      Type: 'mcp'
    }
  }
}

// 12. Hosted Agent Container App (starts empty; deploy the agent image in notebook cells)
resource hostedAgentContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-agent-${resourceSuffix}'
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
        targetPort: 8088
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
          name: 'hosted-agent'
          // Placeholder image – replaced when running the "Build & Deploy" notebook cells
          image: 'docker.io/jfxs/hello-world:latest'
          env: [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: '${apimService.properties.gatewayUrl}/${inferenceAPIPath}'
            }
            {
              name: 'AZURE_OPENAI_CHAT_DEPLOYMENT_NAME'
              value: modelsConfig[0].name
            }
            {
              name: 'AZURE_AI_PROJECT_ENDPOINT'
              value: foundryModule.outputs.extendedAIServicesConfig[1].foundryProjectEndpoint
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: containerAppUAI.properties.clientId
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


// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output applicationInsightsName string = appInsightsModule.outputs.name
output apimSubscriptions array = apimModule.outputs.apimSubscriptions

// Foundry inference project (foundry-inference, has gpt-4.1)
output foundryInferenceProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].foundryProjectEndpoint

// Foundry agent project (foundry-agent, used for hosted agent service)
output foundryAgentProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[1].foundryProjectEndpoint

output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer

output weatherMCPServerContainerAppName string = weatherMCPServerContainerApp.name
output weatherMCPServerFQDN string = weatherMCPServerContainerApp.properties.configuration.ingress.fqdn

output hostedAgentContainerAppName string = hostedAgentContainerApp.name
output hostedAgentFQDN string = hostedAgentContainerApp.properties.configuration.ingress.fqdn

output weatherMCPConnectionId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.CognitiveServices/accounts/${foundryModule.outputs.extendedAIServicesConfig[1].cognitiveServiceName}/projects/${foundryProjectName}-${aiServicesConfig[1].name}/connections/${weatherMCPConnection.name}'
