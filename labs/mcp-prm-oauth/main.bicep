// ------------------
//    PARAMETERS
// ------------------

param appRegName string = 'mcp-prm-app-reg'
param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference' // Path to the inference API in the APIM service
param foundryProjectName string = 'default'

@description('The encryption IV for session token')
@secure()
param encryptionIV string

@description('The encryption key for session token')
@secure()
param encryptionKey string

@description('OAuth scopes for the MCP application')
param oauthScopes string

@description('The display name for the MCP Entra application')
param mcpAppDisplayName string = appRegName

@description('MCP App Client ID - if already created manually, provide it here to skip automatic creation')
param mcpClientId string = ''

@description('Tags to apply to all resources')
param tags object = {}

param location string = resourceGroup().location

param prmAPIPath string = '/mcp'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var mcpAppUniqueName = 'mcp-app-${resourceSuffix}'


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
    apimModule
  ]
}

// 4. User Assigned Managed Identity (for Container App and Web App)
module managedIdentityModule 'src/bicep/identity/userAssignedIdentity.bicep' = {
  name: 'managedIdentityModule'
  params: {
    identityName: 'mi-mcp-${resourceSuffix}'
    location: location
    tags: tags
  }
}

// Reference to the managed identity resource for use in identity blocks
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: 'mi-mcp-${resourceSuffix}'
  dependsOn: [
    managedIdentityModule
  ]
}

// 5. Container Registry
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

// 6. Container App Environment
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

// 7. Role Assignment: ACR Pull for Managed Identity
var acrPullRole = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
@description('This allows the managed identity to pull images from the container registry')
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, managedIdentityModule.name, acrPullRole, containerRegistry.id)
  properties: {
    roleDefinitionId: acrPullRole
    principalId: managedIdentityModule.outputs.identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// 8. MCP Server Container App
resource mcpServerContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-mcp-${resourceSuffix}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        allowInsecure: false
      }
      registries: [
        {
          identity: managedIdentity.id
          server: containerRegistry.properties.loginServer
        }
      ]      
    }
    template: {
      containers: [
        {
          name: 'mcp-server-${resourceSuffix}'
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
  dependsOn: [
    acrPullRoleAssignment
  ]
}

// 9. Entra ID Application Registration for MCP
// NOTE: The Microsoft Graph Bicep extension is experimental and may not be available in all environments.
// If the deployment fails due to Graph extension issues, you have two options:
//   1. Create the Entra App manually and provide the mcpClientId parameter
//   2. Use Azure CLI or PowerShell scripts to create the app registration
// 
// To create manually:
//   - Create an App Registration in Entra ID
//   - Add API permission: user_impersonate (delegated)
//   - Add redirect URI: https://{containerAppFQDN}/auth/callback
//   - Create a federated credential trusting the managed identity
//   - Pass the App ID as mcpClientId parameter
module mcpEntraAppModule 'src/bicep/identity/mcp-entra-app.bicep' = if (empty(mcpClientId)) {
  name: 'mcpEntraAppModule'
  params: {
    mcpAppUniqueName: mcpAppUniqueName
    mcpAppDisplayName: mcpAppDisplayName
    tenantId: subscription().tenantId
    userAssignedIdentityPrincipleId: managedIdentityModule.outputs.identityPrincipalId
    webAppName: mcpServerContainerApp.name
  }
}

// 10. MCP API Configuration in APIM
module mcpApiModule 'src/bicep/apim-mcp/mcp-api.bicep' = {
  name: 'mcpApiModule'
  params: {
    apimServiceName: apimService.name
    webAppName: mcpServerContainerApp.name
    mcpAppId: !empty(mcpClientId) ? mcpClientId : (mcpEntraAppModule.?outputs.mcpAppId ?? '')
    mcpAppTenantId: subscription().tenantId
  }
}


// ------------------
//    OUTPUTS
// ------------------

// Container Infrastructure
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer

output mcpServerContainerAppName string = mcpServerContainerApp.name
output mcpServerContainerAppFQDN string = mcpServerContainerApp.properties.configuration.ingress.fqdn

// Monitoring
output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName
output logAnalyticsWorkspaceId string = lawModule.outputs.customerId

// API Management
output apimServiceId string = apimModule.outputs.id
output apimResourceName string = apimService.name
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions

// Managed Identity
output managedIdentityId string = managedIdentityModule.outputs.identityId
output managedIdentityName string = managedIdentityModule.outputs.identityName
output managedIdentityClientId string = managedIdentityModule.outputs.identityClientId
output managedIdentityPrincipalId string = managedIdentityModule.outputs.identityPrincipalId

// MCP Server URL
output mcpServerURL string = 'https://${mcpServerContainerApp.properties.configuration.ingress.fqdn}'

// MCP Configuration
output mcpAppId string = !empty(mcpClientId) ? mcpClientId : (mcpEntraAppModule.?outputs.mcpAppId ?? 'Not created - provide mcpClientId parameter')
output mcpAppTenantId string = subscription().tenantId
output mcpApiEndpoint string = '${apimModule.outputs.gatewayUrl}${prmAPIPath}'
output mcpPrmEndpoint string = '${apimModule.outputs.gatewayUrl}/.well-known/oauth-protected-resource'


