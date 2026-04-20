/*
Cross-Region Azure OpenAI Connection Module
---------------------------------------------
Creates an Azure OpenAI resource in a different region, deploys a model,
creates a private endpoint + DNS for private connectivity, and routes
through APIM with managed identity auth for agent access.

The APIM gateway approach is required because:
- Azure enforces disableLocalAuth=true on new OpenAI resources (no API keys)
- AzureOpenAI connections don't support the connection/model format for agents
- APIM with managed identity auth bypasses both limitations
*/

@description('Azure region for the cross-region OpenAI resource')
param location string

@description('Name of the AI Foundry account to connect to')
param accountName string

@description('Name of the project')
param projectName string

@description('Name for the cross-region Azure OpenAI resource')
param openAIName string

@description('Custom subdomain name for the OpenAI resource (required for private endpoints)')
param customSubDomainName string = ''

// Model deployment parameters
@description('Model name to deploy')
param modelName string = 'gpt-4o'

@description('Model version')
param modelVersion string = '2024-11-20'

@description('Model SKU')
param modelSkuName string = 'GlobalStandard'

@description('Model capacity (TPM)')
param modelCapacity int = 30

// APIM parameters
@description('Name of the APIM service to route through')
param apimName string

@description('Name for the APIM API (defaults to azure-openai-{location})')
param apimApiName string = ''

@description('Name for the gateway connection on the project (defaults to apim-gateway-{location})')
param connectionName string = ''

@description('API version for inference calls')
param inferenceApiVersion string = '2024-10-21'

@description('APIM subscription name for API key')
param apimSubscriptionKeyName string = 'master'

@description('Inbound policy XML for the APIM API. Should include managed-identity auth to the AI Services backend.')
param policyXml string = '<policies><inbound><base /><authentication-managed-identity resource="https://cognitiveservices.azure.com/" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'

// Private endpoint parameters
@description('VNet name for the private endpoint (in the primary region)')
param vnetName string = ''

@description('Subnet name for the private endpoint')
param peSubnetName string = 'pe-subnet'

@description('Resource group of the VNet')
param vnetResourceGroupName string = resourceGroup().name

// Derived variables
var finalCustomDomain = !empty(customSubDomainName) ? customSubDomainName : openAIName
var createPrivateEndpoint = !empty(vnetName)
var finalApimApiName = !empty(apimApiName) ? apimApiName : 'azure-openai-${location}'
var finalConnectionName = !empty(connectionName) ? connectionName : 'apim-gateway-${location}'

// ---- Azure OpenAI Resource ----
resource openAI 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: openAIName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
    customSubDomainName: finalCustomDomain
  }
}

// ---- Model Deployment ----
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: openAI
  name: modelName
  sku: {
    name: modelSkuName
    capacity: modelCapacity
  }
  properties: {
    model: {
      name: modelName
      format: 'OpenAI'
      version: modelVersion
    }
  }
}

// ---- RBAC: Grant APIM managed identity access to cross-region OpenAI ----
resource apimService 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

// Cognitive Services OpenAI User role
resource apimRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAI.id, apimService.id, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  scope: openAI
  properties: {
    principalId: apimService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  }
}

// ---- APIM API pointing to cross-region backend ----
resource apimApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  name: finalApimApiName
  parent: apimService
  properties: {
    displayName: 'Azure OpenAI ${location}'
    path: 'openai-${location}'
    protocols: [ 'https' ]
    format: 'openapi-link'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/${inferenceApiVersion}/inference.json'
    serviceUrl: 'https://${finalCustomDomain}.openai.azure.com/openai'
    subscriptionRequired: false
  }
}

// ---- APIM API policy: managed identity auth to backend ----
resource apimApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  name: 'policy'
  parent: apimApi
  properties: {
    format: 'xml'
    value: policyXml
  }
}

// ---- Private Endpoint (in the primary VNet) ----
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (createPrivateEndpoint) {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = if (createPrivateEndpoint) {
  name: peSubnetName
  parent: vnet
}

resource openAIPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (createPrivateEndpoint) {
  name: '${openAIName}-private-endpoint'
  location: resourceGroup().location
  properties: {
    subnet: { id: peSubnet.id }
    privateLinkServiceConnections: [
      {
        name: '${openAIName}-private-link-service-connection'
        properties: {
          privateLinkServiceId: openAI.id
          groupIds: [ 'account' ]
        }
      }
    ]
  }
}

resource openAIDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (createPrivateEndpoint) {
  name: '${openAIName}-dns-group'
  parent: openAIPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'openai-dns-config'
        properties: {
          privateDnsZoneId: resourceId('Microsoft.Network/privateDnsZones', 'privatelink.openai.azure.com')
        }
      }
    ]
  }
}

// ---- APIM Gateway Connection on project ----
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
  scope: resourceGroup()
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  name: projectName
  parent: account
}

resource apimMasterSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' existing = {
  name: apimSubscriptionKeyName
  parent: apimService
}

var staticModels = [
  {
    name: modelName
    properties: {
      model: {
        name: modelName
        version: modelVersion
        format: 'OpenAI'
      }
    }
  }
]

resource gatewayConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  name: finalConnectionName
  parent: project
  properties: {
    category: 'ApiManagement'
    target: '${apimService.properties.gatewayUrl}/${apimApi.properties.path}'
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: apimMasterSubscription.listSecrets(apimMasterSubscription.apiVersion).primaryKey
    }
    metadata: {
      deploymentInPath: 'true'
      inferenceAPIVersion: inferenceApiVersion
      models: string(staticModels)
    }
  }
  dependsOn: [
    modelDeployment
    apimApiPolicy
    apimRoleAssignment
  ]
}

output openAIName string = openAI.name
output openAIEndpoint string = openAI.properties.endpoint
output connectionName string = gatewayConnection.name
output modelDeploymentName string = modelDeployment.name
output apimApiPath string = apimApi.properties.path
