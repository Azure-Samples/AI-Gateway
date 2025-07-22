// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference' // Path to the inference API in the APIM service
param foundryProjectName string = 'default'


param githubAPIPath string = 'github'
param weatherAPIPath string = 'weather'
param oncallAPIPath string = 'oncall'
param servicenowAPIPath string = 'servicenow'
param serviceNowInstanceName string

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

// 5. APIM Inference API
module inferenceAPIModule '../../modules/apim/v2/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: 'apim-${resourceSuffix}'
  dependsOn: [
    inferenceAPIModule
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

resource gitHubMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-github-${resourceSuffix}'
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
              value: '${apimService.properties.gatewayUrl}/${githubAPIPath}'
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
              value: 'http://www.bing.com'
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

resource servicenowMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = if (length(serviceNowInstanceName) > 0) {
  name: 'aca-servicenow-${resourceSuffix}'
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
              value: '${apimService.properties.gatewayUrl}/${servicenowAPIPath}'
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
              value: 'http://www.bing.com'
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



module githubAPIModule 'src/github/apim-api/api.bicep' = {
  name: 'githubAPIModule'
  params: {
    apimServiceName: apimService.name
    APIPath: githubAPIPath
    APIServiceURL: 'https://${gitHubMCPServerContainerApp.properties.configuration.ingress.fqdn}/${githubAPIPath}'
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

module serviceNowAPIModule 'src/servicenow/apim-api/api.bicep' = if(length(serviceNowInstanceName) > 0) {
  name: 'servicenowAPIModule'
  params: {
    apimServiceName: apimService.name
    APIPath: servicenowAPIPath
    APIServiceURL: 'https://${servicenowMCPServerContainerApp.properties.configuration.ingress.fqdn}/${servicenowAPIPath}'
    serviceNowInstanceName: serviceNowInstanceName
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

output gitHubMCPServerContainerAppResourceName string = gitHubMCPServerContainerApp.name
output gitHubMCPServerContainerAppFQDN string = gitHubMCPServerContainerApp.properties.configuration.ingress.fqdn

output weatherMCPServerContainerAppResourceName string = weatherMCPServerContainerApp.name
output weatherMCPServerContainerAppFQDN string = weatherMCPServerContainerApp.properties.configuration.ingress.fqdn

output oncallMCPServerContainerAppResourceName string = oncallMCPServerContainerApp.name
output oncallMCPServerContainerAppFQDN string = oncallMCPServerContainerApp.properties.configuration.ingress.fqdn

output servicenowMCPServerContainerAppResourceName string = (length(serviceNowInstanceName) > 0) ? servicenowMCPServerContainerApp.name: ''
output servicenowMCPServerContainerAppFQDN string = (length(serviceNowInstanceName) > 0) ? servicenowMCPServerContainerApp.properties.configuration.ingress.fqdn: ''

output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceName string = apimService.name
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output foundryProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].foundryProjectEndpoint

