// ------------------
//    PARAMETERS
// ------------------

@description('Configuration array for AI Foundry resources')
param aiServicesConfig array = []

@description('Configuration array for the model deployments')
param modelsConfig array = []

@description('The SKU of the API Management instance')
param apimSku string

@description('Configuration array for APIM subscriptions')
param apimSubscriptionsConfig array = []

@description('The inference API type')
param inferenceAPIType string = 'AzureOpenAIV1'

@description('The path to the inference API in the APIM service')
param inferenceAPIPath string = 'foundry'

@description('AI Foundry project name')
param foundryProjectName string = 'default'

@description('The authentication type the gateway enforces: EntraID (developer token + group check + MI swap + PRM discovery) or ApiKey (APIM subscription key + MI swap)')
@allowed([
  'EntraID'
  'ApiKey'
])
param authType string = 'EntraID'

@description('The Entra tenant id used to validate the developer token (EntraID auth only)')
param tenantId string = ''

@description('The object id of the Entra security group whose members may use the gateway (EntraID auth only)')
param allowedGroupId string = ''

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
  }
}

// 5. APIM Inference API
// The policy is the gateway's authentication gate. For EntraID, the {tenant-id} and
// {group-id} placeholders are substituted here; {backend-id} is substituted inside the
// module. Both policies configure the backend with APIM's managed-identity credentials,
// which performs the token swap (caller credential -> APIM MI token) when calling Foundry
// and emit the SAME copilot token metrics + trace, so one FinOps workbook serves both.
module inferenceAPIModule '../../modules/apim/v3/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: (authType == 'EntraID') ? replace(replace(loadTextContent('entra-policy.xml'), '{tenant-id}', tenantId), '{group-id}', allowedGroupId) : loadTextContent('apikey-policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}

// 6. PRM discovery endpoint (RFC 9728) — EntraID auth only
// An anonymous API served at https://<gateway>/.well-known/oauth-protected-resource.
// Discovery-capable clients (GitHub Copilot BYOK, OpenCode, ...) fetch it after a 401
// to learn the resource + authorization server, then run interactive OAuth + PKCE.
// API-key auth has no interactive OAuth flow, so this is skipped in that mode.
resource apimServiceRef 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: 'apim-${uniqueString(subscription().id, resourceGroup().id)}'
  dependsOn: [
    apimModule
  ]
}

resource prmApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = if (authType == 'EntraID') {
  parent: apimServiceRef
  name: 'oauth-protected-resource-metadata'
  properties: {
    displayName: 'OAuth Protected Resource Metadata'
    description: 'RFC 9728 Protected Resource Metadata for OAuth discovery'
    subscriptionRequired: false
    path: '/.well-known/oauth-protected-resource'
    protocols: [
      'https'
    ]
  }
  dependsOn: [
    inferenceAPIModule
  ]
}

resource prmOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = if (authType == 'EntraID') {
  parent: prmApi
  name: 'get-oauth-protected-resource'
  properties: {
    displayName: 'Get Protected Resource Metadata'
    method: 'GET'
    urlTemplate: '/'
    description: 'Returns the Protected Resource Metadata document (RFC 9728)'
  }
}

resource prmOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = if (authType == 'EntraID') {
  parent: prmOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(loadTextContent('prm-policy.xml'), '{tenant-id}', tenantId)
  }
}

// 7. FinOps workbook
// Renders per-developer usage & cost reports from the telemetry the gateway already
// emits (per-user token metrics + the copilot-finops trace joined to the LLM logs).
// No data seeding - every widget is driven by real gateway traffic. Bound to App
// Insights, which is workspace-based, so customMetrics and the ApiManagementGateway*
// tables are queryable together.
resource finOpsWorkbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid(resourceGroup().id, 'ghcp-byok-foundry-finops')
  location: resourceGroup().location
  kind: 'shared'
  properties: {
    displayName: 'Copilot FinOps - per-developer usage & cost'
    serializedData: replace(loadTextContent('workbook.json'), '{workspaceResourceId}', lawModule.outputs.id)
    category: 'workbook'
    sourceId: appInsightsModule.outputs.id
    version: 'Notebook/1.0'
  }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output applicationInsightsAppId string = appInsightsModule.outputs.appId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions

// Used by the notebook to grant the APIM managed identity the Graph permission
output apimPrincipalId string = apimModule.outputs.principalId

// Used by the notebook to demonstrate the "no bypass" behaviour (direct call => 401)
output foundryEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].endpoint

// Used by the notebook to open the FinOps workbook in the Azure portal
output finOpsWorkbookId string = finOpsWorkbook.id

// The authentication mode the gateway was deployed with (EntraID or ApiKey)
output authType string = authType

// PRM (RFC 9728) discovery document — clients fetch this after a 401 to start OAuth
// (EntraID auth only; empty for ApiKey since there is no interactive OAuth flow)
output prmDiscoveryUrl string = (authType == 'EntraID') ? '${apimModule.outputs.gatewayUrl}/.well-known/oauth-protected-resource' : ''
