/*
APIM Gateway Connection Module
-------------------------------
Creates an Azure OpenAI API in APIM and a gateway connection on the Foundry project.

This follows the pattern from:
- https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/ai-gateway
- infrastructure-setup-bicep/01-connections/apim/connection-apim.bicep

The connection enables Foundry Agents to route model requests through APIM
using the model name format: <connection-name>/<model-deployment-name>
*/

// ---- Project parameters ----
@description('Name of the AI Foundry account')
param accountName string

@description('Name of the project')
param projectName string

// ---- APIM parameters ----
@description('Name of the API Management service')
param apimName string

@description('APIM subscription name for retrieving API keys')
param apimSubscriptionKeyName string = 'master'

// ---- AI Services parameters ----
@description('The Azure OpenAI endpoint for the AI Services account (e.g., https://<name>.openai.azure.com)')
param aiServicesEndpoint string

// ---- Connection configuration ----
@description('Name for the gateway connection on the project')
param connectionName string = 'apim-gateway'

@description('Name for the API in APIM')
param apimApiName string = 'azure-openai'

@description('API version for inference calls (chat completions)')
param inferenceApiVersion string = '2024-10-21'

@description('Whether deployment name is in the URL path (true for Azure OpenAI format)')
param deploymentInPath string = 'true'

@description('Share connection with all project users')
param isSharedToAll bool = true

@description('Static model deployments to expose through the gateway')
param modelDeployments array = []

@description('Inbound policy XML for the APIM API. Should include managed-identity auth to the AI Services backend.')
param policyXml string = '<policies><inbound><base /><authentication-managed-identity resource="https://cognitiveservices.azure.com/" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'

// ---- Resource references ----
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
  scope: resourceGroup()
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  name: projectName
  parent: account
}

resource apimService 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource apimMasterSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' existing = {
  name: apimSubscriptionKeyName
  parent: apimService
}

// ---- Import Azure OpenAI API into APIM ----
resource apimApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  name: apimApiName
  parent: apimService
  properties: {
    displayName: 'Azure OpenAI Service API'
    path: 'openai'
    protocols: [ 'https' ]
    format: 'openapi-link'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/${inferenceApiVersion}/inference.json'
    serviceUrl: '${aiServicesEndpoint}/openai'
    // Require an APIM subscription key for direct callers (e.g. the jump-box
    // test scripts). The Foundry project connection still uses the APIM master
    // subscription key, whose scope covers all APIs.
    subscriptionRequired: true
    // Accept the Azure OpenAI native 'api-key' header (and 'api-key' query
    // parameter) as the subscription key so the openai SDK's AzureOpenAI
    // client works without custom headers. The default APIM header
    // 'Ocp-Apim-Subscription-Key' is still accepted in addition.
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
  }
}

// ---- Dedicated APIM subscription scoped to this API for direct testing ----
resource apiSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  name: '${apimApiName}-test'
  parent: apimService
  properties: {
    displayName: 'Direct test access to ${apimApiName}'
    scope: apimApi.id
    state: 'active'
    allowTracing: false
  }
}

// ---- APIM managed identity auth to AI Services backend ----
resource apimApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  name: 'policy'
  parent: apimApi
  properties: {
    format: 'xml'
    value: policyXml
  }
}

// ---- Grant APIM managed identity Cognitive Services OpenAI User on AI Services ----
resource aiAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource apimOpenAIUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiAccount.id, apimService.id, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  scope: aiAccount
  properties: {
    principalId: apimService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  }
}

// ---- Build connection metadata ----
var hasModels = length(modelDeployments) > 0
var metadata = union(
  {
    deploymentInPath: deploymentInPath
    inferenceAPIVersion: inferenceApiVersion
  },
  hasModels ? {
    models: string(modelDeployments)
  } : {}
)

// ---- Create APIM gateway connection on project ----
resource apimConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  name: connectionName
  parent: project
  properties: {
    category: 'ApiManagement'
    target: '${apimService.properties.gatewayUrl}/${apimApi.properties.path}'
    authType: 'ApiKey'
    isSharedToAll: isSharedToAll
    credentials: {
      key: apimMasterSubscription.listSecrets(apimMasterSubscription.apiVersion).primaryKey
    }
    metadata: metadata
  }
}

output connectionName string = apimConnection.name
output targetUrl string = '${apimService.properties.gatewayUrl}/${apimApi.properties.path}'
output apimApiName string = apimApi.name
output apimApiPath string = apimApi.properties.path

@secure()
output apiSubscriptionKey string = apiSubscription.listSecrets(apiSubscription.apiVersion).primaryKey
