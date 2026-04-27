// ------------------
//    PARAMETERS
// ------------------


param apimSku string
param apimSubscriptionsConfig array = []
param geminiApiKey string = '123456'
param geminiPath string = 'gemini/openai'

param weatherAPIPath string = 'weather'
param oncallAPIPath string = 'oncall'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var policyXml = loadTextContent('policy.xml')
var logSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens' , 'x-ratelimit-remaining-requests' ]
  body: { bytes: 8192 }
}


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

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: 'apim-${resourceSuffix}'
  dependsOn: [
    lawModule
    apimModule
  ]
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource openAIAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'openai-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'OpenAI Inference API - Gemini'
    displayName: 'Gemini - OpenAI'
    format: 'openapi+json-link'
    path: geminiPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: 'https://raw.githubusercontent.com/nourshaker-msft/sk_a2a_mcp/refs/heads/main/openai-openapi.json'
  }
  dependsOn: [
    apimService
  ]
}

// Create diagnostics only if we have an App Insights ID and instrumentation key.
resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: openAIAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apimService.name, 'appinsights-logger')
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

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis/policies
resource openAIAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: openAIAPI
  properties: {
    format: 'rawxml'
    value: policyXml
  }
  dependsOn: [
    backendGemini
  ]
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendGemini 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'gemini-backend'
  parent: apimService
  properties: {
    description: 'Backend for the Gemini API'
    url: 'https://generativelanguage.googleapis.com/v1beta/openai'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 1
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
          acceptRetryAfter: true
        }
      ]
    }
    credentials: {
      header: {
        Authorization: ['{{gemini-api-key}}']
      }
    }
  }
  dependsOn: [
    namedValueGeminiAPIKey
    apimService
  ]
}

resource namedValueGeminiAPIKey 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  name: 'gemini-api-key'
  parent: apimService
  properties: {
    displayName: 'Gemini-API-Key'
    value: 'Bearer ${geminiApiKey}'
    secret: true
    tags: [
      'gemini'
    ]
  }
  dependsOn: [
    apimService
  ]
} 

resource contentSafetyResource 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: 'contentsafety-${resourceSuffix}'
  location: resourceGroup().location
  sku: {
    name: 'S0'
  }
  kind: 'ContentSafety'
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: toLower('contentsafety-${resourceSuffix}')
  }
}

var cognitiveServicesReaderDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
resource contentSafetyRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: contentSafetyResource
  name: guid(subscription().id, resourceGroup().id, contentSafetyResource.name, cognitiveServicesReaderDefinitionID)
  properties: {
      roleDefinitionId: cognitiveServicesReaderDefinitionID
      principalId: apimService.identity.principalId
      principalType: 'ServicePrincipal'
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource contentSafetyBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'content-safety-backend'
  parent: apimService
  properties: {
    description: 'Content Safety Backend'
    url: contentSafetyResource.properties.endpoint
    protocol: 'http'
  }
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

resource oncallMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-oncall-${resourceSuffix}'
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

module weatherAPIModule 'src/weather/apim-api/api.bicep' = {
  name: 'weatherAPIModule'
  params: {
    apimServiceName: apimService.name
    APIPath: weatherAPIPath
    APIServiceURL: 'https://${weatherMCPServerContainerApp.properties.configuration.ingress.fqdn}/${weatherAPIPath}'
  }
}

module oncallAPIModule 'src/oncall/apim-api/api.bicep' = {
  name: 'oncallAPIModule'
  params: {
    apimServiceName: apimService.name
    APIPath: oncallAPIPath
    APIServiceURL: 'https://${oncallMCPServerContainerApp.properties.configuration.ingress.fqdn}/${oncallAPIPath}'
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

output containerRegistryName string = containerRegistry.name

output weatherMCPServerContainerAppResourceName string = weatherMCPServerContainerApp.name
output weatherMCPServerContainerAppFQDN string = weatherMCPServerContainerApp.properties.configuration.ingress.fqdn

output oncallMCPServerContainerAppResourceName string = oncallMCPServerContainerApp.name
output oncallMCPServerContainerAppFQDN string = oncallMCPServerContainerApp.properties.configuration.ingress.fqdn

output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceName string = apimService.name
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

output apimSubscriptions array = apimModule.outputs.apimSubscriptions
