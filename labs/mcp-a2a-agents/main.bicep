// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apimSku string
param apimLoggerName string = 'apim-logger'
param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIModelSKU string
param openAIDeploymentName string
param openAIAPIVersion string = '2024-02-01'

param location string = resourceGroup().location

param weatherAPIPath string = 'weather'
param oncallAPIPath string = 'oncall'

param a2aweatherAPIPath string = 'weather-agent-a2a'
param a2aoncallAPIPath string = 'oncall-agent-a2a'

param mcpweatherAPIPath string = 'weather-agent-mcp'
param mcponcallAPIPath string = 'oncall-agent-mcp'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'
var openAIAPIName = 'openai'

// Account for all placeholders in the polixy.xml file.
var policyXml = loadTextContent('policy.xml')
var updatedPolicyXml = replace(policyXml, '{backend-id}', (length(openAIConfig) > 1) ? 'openai-backend-pool' : openAIConfig[0].name)

// ------------------
//    RESOURCES
// ------------------

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'acr${resourceSuffix}'
  location: location
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
  location: location
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
  location: location
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

resource weatherMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-weather-tools-${resourceSuffix}'
  location: location
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

resource oncallMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-oncall-tools-${resourceSuffix}'
  location: location
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

// A2A Container Apps resources

resource A2AWeatherAgentServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-weather-agent-${resourceSuffix}'
  location: location
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
        targetPort: 9090
        allowInsecure: true
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

resource A2AOncallAgentServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-oncall-agent-${resourceSuffix}'
  location: location
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
        targetPort: 9090
        allowInsecure: true
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

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

var lawId = lawModule.outputs.id

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawId
    customMetricsOptedInType: 'WithDimensions'
  }
}


// ------------------
//    RESOURCES
// ------------------

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementName
  location: location
  sku: {
    name: apimSku
    capacity: 1
  }
  properties: {
    publisherEmail: 'noreply@microsoft.com'
    publisherName: 'Microsoft'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Create a logger only if we have an App Insights ID and instrumentation key.
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: apimLoggerName
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: appInsightsModule.outputs.instrumentationKey
    }
    description: 'APIM Logger'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: appInsightsModule.outputs.id
  }
}

// 4. Cognitive Services
module openAIModule '../../modules/cognitive-services/v1/openai.bicep' = {
    name: 'openAIModule'
    params: {
      openAIConfig: openAIConfig
      openAIDeploymentName: openAIDeploymentName
      openAIModelName: openAIModelName
      openAIModelVersion: openAIModelVersion
      openAIModelSKU: openAIModelSKU
      apimPrincipalId: apimService.identity.principalId
      lawId: lawId
    }
  }

// 5. APIM OpenAI API
module openAIAPIModule '../../modules/apim/v1/openai-api.bicep' = {
  name: 'openAIAPIModule'
  params: {
    policyXml: updatedPolicyXml
    openAIConfig: openAIModule.outputs.extendedOpenAIConfig
    openAIAPIVersion: openAIAPIVersion
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
    appInsightsId: appInsightsModule.outputs.id
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' existing = {
  parent: apimService
  name: openAIAPIName
  dependsOn: [
    openAIAPIModule
  ]
}

module weatherAPIModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'weatherAPIModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: weatherAPIPath
    MCPServiceURL: 'https://${weatherMCPServerContainerApp.properties.configuration.ingress.fqdn}/${weatherAPIPath}'
  }
}

module oncallAPIModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'oncallAPIModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: oncallAPIPath
    MCPServiceURL: 'https://${oncallMCPServerContainerApp.properties.configuration.ingress.fqdn}/${oncallAPIPath}'
  }
}

// A2A APIs
module WeatherAgentA2AAPI 'src/a2a_servers/apim-api/api.bicep' = {
  name: 'WeatherAgentA2AAPI'
  params: {
    apimServiceName: apimService.name
    agentName: a2aweatherAPIPath
    APIPath: a2aweatherAPIPath
    APIServiceURL: 'https://${A2AWeatherAgentServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

module a2aOncallAPIModule 'src/a2a_servers/apim-api/api.bicep' = {
  name: 'a2aOncallAPIModule'
  params: {
    apimServiceName: apimService.name
    agentName: a2aoncallAPIPath
    APIPath: a2aoncallAPIPath
    APIServiceURL: 'https://${A2AOncallAgentServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

module WeatherAgentMCPAPI 'src/mcp_sk_servers/apim-mcp/mcp-api.bicep' = {
  name: 'WeatherAgentMCPAPI'
  params: {
    apimServiceName: apimService.name
    APIPath: mcpweatherAPIPath
    agentName: mcpweatherAPIPath
    acaContainerAppURL: 'https://${A2AWeatherAgentServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

module OncallAgentMCPAPI 'src/mcp_sk_servers/apim-mcp/mcp-api.bicep' = {
  name: 'OncallAgentMCPAPI'
  params: {
    apimServiceName: apimService.name
    APIPath: mcponcallAPIPath
    agentName: mcponcallAPIPath
    acaContainerAppURL: 'https://${A2AOncallAgentServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

// Ignore the subscription that gets created in the APIM module and create three new ones for this lab.
resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'apim-subscription'
  parent: apimService
  properties: {
    allowTracing: true
    displayName: 'Generic APIM Subscription'
    scope: '/apis'
    state: 'active'
  }
  dependsOn: [
    api
  ]
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

output containerRegistryName string = containerRegistry.name

output weatherMCPServerContainerAppResourceName string = weatherMCPServerContainerApp.name
output weatherMCPServerContainerAppFQDN string = weatherMCPServerContainerApp.properties.configuration.ingress.fqdn

output oncallMCPServerContainerAppResourceName string = oncallMCPServerContainerApp.name
output oncallMCPServerContainerAppFQDN string = oncallMCPServerContainerApp.properties.configuration.ingress.fqdn

//A2ASkWeatherAgentServerContainerApp
output a2AWeatherAgentServerContainerAppResourceName string = A2AWeatherAgentServerContainerApp.name
output a2AWeatherAgentServerContainerAppFQDN string = A2AWeatherAgentServerContainerApp.properties.configuration.ingress.fqdn

//A2ASkOncallAgentServerContainerApp
output a2AOncallAgentServerContainerAppResourceName string = A2AOncallAgentServerContainerApp.name
output a2AOncallAgentServerContainerAppFQDN string = A2AOncallAgentServerContainerApp.properties.configuration.ingress.fqdn

output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName
output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimService.id
output apimResourceName string = apimService.name
output apimResourceGatewayURL string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey
