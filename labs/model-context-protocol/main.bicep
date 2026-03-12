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

param databricksAuthorizationProviderName string = 'databricks'
param databricksGeniePath string = 'genie'
param gitHubAuthorizationProviderName string = 'github'
param githubPath string = 'github'
param weatherPath string = 'weather'
param oncallPath string = 'oncall'
param servicenowPath string = 'servicenow'
param serviceNowInstanceName string = ''

param confluenceAuthorizationProviderName string = 'confluence'
param confluencePath string = 'confluence'
param jiraAuthorizationProviderName string = 'jira'
param jiraPath string = 'jira'

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

resource credentialManagerClientContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-cm-client-${resourceSuffix}'
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
              name: 'AUTHORIZATION_PROVIDER_ID'
              value: databricksAuthorizationProviderName
            } 
            {
              name: 'POST_LOGIN_REDIRECT_URL'
              value: 'https://learn.microsoft.com/en-us/azure/api-management/get-authorization-context-policy'
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

resource genieMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-genie-${resourceSuffix}'
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
              name: 'GENIE_SPACE_ID'
              value: 'changeme'
            }
            {
              name: 'APIM_GATEWAY_URL'
              value: '${apimService.properties.gatewayUrl}/${databricksGeniePath}/api'
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
              name: 'AUTHORIZATION_PROVIDER_ID'
              value: databricksAuthorizationProviderName
            } 
            {
              name: 'POST_LOGIN_REDIRECT_URL'
              value: 'http://www.databricks.com'
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

resource confluenceMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-confluence-${resourceSuffix}'
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
              value: '${apimService.properties.gatewayUrl}/${confluencePath}/api'
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
              name: 'AUTHORIZATION_PROVIDER_ID'
              value: confluenceAuthorizationProviderName
            } 
            {
              name: 'POST_LOGIN_REDIRECT_URL'
              value: 'http://www.adidas.com'
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

resource jiraMCPServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-jira-${resourceSuffix}'
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
              value: '${apimService.properties.gatewayUrl}/${jiraPath}/api'
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
              name: 'AUTHORIZATION_PROVIDER_ID'
              value: jiraAuthorizationProviderName
            } 
            {
              name: 'POST_LOGIN_REDIRECT_URL'
              value: 'http://www.adidas.com'
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
              value: '${apimService.properties.gatewayUrl}/${githubPath}/api'
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
              name: 'AUTHORIZATION_PROVIDER_ID'
              value: gitHubAuthorizationProviderName
            } 
            {
              name: 'POST_LOGIN_REDIRECT_URL'
              value: 'http://www.github.com'
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
              value: '${apimService.properties.gatewayUrl}/${servicenowPath}/api'
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

module confluenceAPIModule './src/confluence/apim-api/api.bicep' = {
  name: 'confluenceAPIModule'
  params: {
    apimServiceName: apimService.name
    APIPath: confluencePath
    APIServiceURL: 'https://api.atlassian.com'
    authorizationProviderName: confluenceAuthorizationProviderName
  }
}

module confluenceMCPModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'confluenceMCPModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: confluencePath
    MCPServiceURL: 'https://${confluenceMCPServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

module jiraAPIModule './src/jira/apim-api/api.bicep' = {
  name: 'jiraAPIModule'
  params: {
    apimServiceName: apimService.name
    APIPath: jiraPath
    APIServiceURL: 'https://api.atlassian.com'
    authorizationProviderName: jiraAuthorizationProviderName
  }
}

module jiraMCPModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'jiraMCPModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: jiraPath
    MCPServiceURL: 'https://${jiraMCPServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

module genieAPIModule './src/databricks-genie/apim-api/api.bicep' = {
  name: 'genieAPIModule'
  params: {
    apimServiceName: apimService.name
    APIPath: databricksGeniePath
    APIServiceURL: 'https://api.databricks.com'
    authorizationProviderName: databricksAuthorizationProviderName
  }
}

module genieMCPModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'genieMCPModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: databricksGeniePath
    MCPServiceURL: 'https://${genieMCPServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

module githubAPIModule './src/github/apim-api/api.bicep' = {
  name: 'githubAPIModule'
  params: {
    apimServiceName: apimService.name
    APIPath: githubPath
    APIServiceURL: 'https://api.github.com'
    authorizationProviderName: gitHubAuthorizationProviderName
  }
}

module githubMCPModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'githubMCPModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: githubPath
    MCPServiceURL: 'https://${gitHubMCPServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

module weatherMCPModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'weatherMCPModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: weatherPath
    MCPServiceURL: 'https://${weatherMCPServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

module oncallMCPModule '../../modules/apim-streamable-mcp/api.bicep' = {
  name: 'oncallMCPModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: oncallPath
    MCPServiceURL: 'https://${oncallMCPServerContainerApp.properties.configuration.ingress.fqdn}'
  }
}

module servicenowAPIModule './src/servicenow/apim-api/api.bicep' = if(length(serviceNowInstanceName) > 0) {
  name: 'servicenowAPIModule'
  params: {
    apimServiceName: apimService.name
    APIPath: servicenowPath
    APIServiceURL: 'https://api.servicenow.com'
    serviceNowInstanceName: serviceNowInstanceName
  }
}

module serviceNowMCPModule '../../modules/apim-streamable-mcp/api.bicep' = if(length(serviceNowInstanceName) > 0) {
  name: 'servicenowMCPModule'
  params: {
    apimServiceName: apimService.name
    MCPPath: servicenowPath
    MCPServiceURL: 'https://${servicenowMCPServerContainerApp.properties.configuration.ingress.fqdn}/${servicenowPath}/mcp'    
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

output genieMCPServerContainerAppResourceName string = genieMCPServerContainerApp.name
output genieMCPServerContainerAppFQDN string = genieMCPServerContainerApp.properties.configuration.ingress.fqdn

output confluenceMCPServerContainerAppResourceName string = confluenceMCPServerContainerApp.name
output confluenceMCPServerContainerAppFQDN string = confluenceMCPServerContainerApp.properties.configuration.ingress.fqdn

output jiraMCPServerContainerAppResourceName string = jiraMCPServerContainerApp.name
output jiraMCPServerContainerAppFQDN string = jiraMCPServerContainerApp.properties.configuration.ingress.fqdn

output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceName string = apimService.name
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

output apimSubscriptions array = apimModule.outputs.apimSubscriptions

output foundryProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].foundryProjectEndpoint
