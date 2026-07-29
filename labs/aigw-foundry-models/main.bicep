// ------------------
//    PARAMETERS
// ------------------

param workspaceName string = 'default'
param foundryProjectName string = 'default'
param foundryAccountsConfig array = []
param modelsConfig array = []
param apiKeysConfig array = []
param payloadCapture bool = false

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
    azureMonitorWorkspaceIngestionMode: 'Enabled'
  }
}

// 3. Microsoft Foundry
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
  name: 'foundryModule'
  params: {
    aiServicesConfig: foundryAccountsConfig
    modelsConfig: modelsConfig
    foundryProjectName: foundryProjectName
  }
}

// 4. AI Gateway
module aiGatewayModule '../../modules/ai-gateway/v1/ai-gateway.bicep' = {
  name: 'aiGatewayModule'
  params: {
    workspaceName: workspaceName
    apiKeysConfig: apiKeysConfig
    appInsightsId: appInsightsModule.outputs.id
    payloadCapture: payloadCapture
    foundryAccountsConfig: foundryModule.outputs.extendedAIServicesConfig
  }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = aiGatewayModule.outputs.id
output apimResourceGatewayURL string = aiGatewayModule.outputs.gatewayUrl
output gatewayPrincipalId string = aiGatewayModule.outputs.principalId
output appInsightsId string = appInsightsModule.outputs.id
output apiKeys array = aiGatewayModule.outputs.apiKeys
