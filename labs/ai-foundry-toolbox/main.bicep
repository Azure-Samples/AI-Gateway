// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference'
param foundryProjectName string = 'default'
param toolboxName string = 'vet-toolbox'

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

// 3. API Management
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

// 5. APIM Inference API
module inferenceAPIModule '../../modules/apim/v3/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}

// 6. Storage Account for Flex Consumption Function App deployment packages
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${resourceSuffix}'
  location: resourceGroup().location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'deployments'
  properties: { publicAccess: 'None' }
}

// 7. Flex Consumption App Service Plan
resource flexConsumptionPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'flex-plan-${resourceSuffix}'
  location: resourceGroup().location
  kind: 'linux'
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

// 8. Vet Toolbox Function App (Flex Consumption, Python 3.12)
resource vetToolboxFunctionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-${resourceSuffix}'
  location: resourceGroup().location
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: flexConsumptionPlan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}deployments'
          authentication: { type: 'SystemAssignedIdentity' }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 40
        instanceMemoryMB: 2048
      }
      runtime: { name: 'python', version: '3.12' }
    }
    siteConfig: {
      appSettings: [
        { name: 'AzureWebJobsStorage__accountName', value: storageAccount.name }
        { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsModule.outputs.connectionString }
      ]
    }
  }
  dependsOn: [deploymentContainer]
}

// 9. Grant Function App managed identity Storage Blob Data Owner on the storage account
resource storageBlobDataOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(subscription().id, resourceGroup().id, vetToolboxFunctionApp.id, 'StorageBlobDataOwner')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner
    principalId: vetToolboxFunctionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// 10. APIM: Toolbox MCP proxy — backend pointing to Foundry Toolbox MCP endpoint
var foundryAccountName = foundryModule.outputs.extendedAIServicesConfig[0].cognitiveServiceName
var foundryProjectPath = '${foundryProjectName}-${aiServicesConfig[0].name}'
var toolboxMcpBackendUrl = 'https://${foundryAccountName}.services.ai.azure.com/api/projects/${foundryProjectPath}/toolboxes/${toolboxName}/mcp'
var toolboxNativeMcpPath = 'toolbox/mcp-native'

// Reference existing APIM service (created by apimModule)
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [apimModule]
}

resource toolboxMcpBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apimService
  name: 'toolbox-mcp-backend'
  properties: {
    protocol: 'http'
    url: toolboxMcpBackendUrl
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource toolboxMcpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apimService
  name: 'foundry-toolbox-mcp'
  properties: {
    displayName: 'Foundry Toolbox MCP'
    description: 'APIM proxy for the Foundry Toolbox MCP endpoint — subscription key auth replaces Entra token requirement'
    type: 'http'
    subscriptionRequired: true
    serviceUrl: toolboxMcpBackendUrl
    path: 'toolbox/mcp'
    protocols: ['https']
  }
}

resource toolboxMcpApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: toolboxMcpApi
  name: 'policy'
  properties: {
    value: loadTextContent('toolbox-policy.xml')
    format: 'rawxml'
  }
}

// 11. APIM native MCP Server (appears in APIM "MCP Servers" blade)
resource toolboxNativeMcpServer 'Microsoft.ApiManagement/service/apis@2025-09-01-preview' = {
  parent: apimService
  name: 'foundry-toolbox-mcp-native'
  properties: {
    displayName: 'Foundry Toolbox MCP (Native)'
    description: 'Native APIM MCP server wrapping the Foundry Toolbox endpoint'
    type: 'mcp'
    subscriptionRequired: true
    backendId: toolboxMcpBackend.name
    path: toolboxNativeMcpPath
    protocols: ['https']
    mcpProperties: {
      endpoints: {
        message: {
          uriTemplate: '/mcp'
        }
      }
    }
  }
}

resource toolboxNativeMcpServerPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: toolboxNativeMcpServer
  name: 'policy'
  properties: {
    value: loadTextContent('toolbox-policy.xml')
    format: 'rawxml'
  }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output foundryProjectEndpoint string = 'https://${foundryAccountName}.services.ai.azure.com/api/projects/${foundryProjectPath}'
output functionAppName string = vetToolboxFunctionApp.name
output functionAppUrl string = 'https://${vetToolboxFunctionApp.properties.defaultHostName}'
