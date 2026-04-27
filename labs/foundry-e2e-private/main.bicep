/*
================================================================================
  AI Gateway Lab: Microsoft Foundry End-to-End Private with APIM AI Gateway
================================================================================
  Adapted from foundry-samples/19-hybrid-private-resources-agent-setup.

  Deploys:
   - VNet with agent / pe / mcp / apim / bastion / jumpbox subnets
   - Microsoft Foundry account + project, with networkInjections to private VNet
   - Backend resources (AI Search, Cosmos DB, Storage) behind private endpoints
   - APIM StandardV2 with VNet integration + private endpoint
   - APIM gateway connection on the Foundry project (apim-gateway/<model>)
   - Optional cross-region OpenAI account exposed through APIM
   - Application Insights + Log Analytics (connected for agent tracing)
   - Optional Azure Bastion + Windows jumpbox VM
================================================================================
*/

// ---------------------------------------------------------------------------
// Core parameters
// ---------------------------------------------------------------------------
@description('Primary Azure region for all resources.')
param location string = resourceGroup().location

@description('Azure region for the cross-region OpenAI resource (when deployCrossRegionOpenAI is true).')
param locationCrossRegion string = 'swedencentral'

@description('Base name for the AI Services account (will be suffixed with a unique string).')
param aiServicesName string = 'aiservices'

@description('Base name for the Foundry project (will be suffixed with a unique string).')
param foundryProjectName string = 'project'

@description('The provider of your model.')
param modelFormat string = 'OpenAI'

@description('Model name to deploy on the primary Foundry account.')
param modelName string = 'gpt-4o-mini'

@description('Model version.')
param modelVersion string = '2024-07-18'

@description('Model SKU (e.g. GlobalStandard, Standard).')
param modelSkuName string = 'GlobalStandard'

@description('Tokens-per-minute capacity for the model deployment.')
param modelCapacity int = 30

// ---------------------------------------------------------------------------
// Networking parameters
// ---------------------------------------------------------------------------
@description('Virtual Network name.')
param vnetName string = 'foundry-e2e-vnet'

@description('Address space for the VNet.')
param vnetAddressPrefix string = '192.168.0.0/16'

@description('Subnet for the Foundry agent (Data Proxy).')
param agentSubnetName string = 'agent-subnet'
param agentSubnetPrefix string = '192.168.0.0/24'

@description('Subnet for private endpoints.')
param peSubnetName string = 'pe-subnet'
param peSubnetPrefix string = '192.168.1.0/24'

@description('Subnet reserved for MCP / Container App workloads.')
param mcpSubnetName string = 'mcp-subnet'
param mcpSubnetPrefix string = '192.168.2.0/24'

@description('Subnet for APIM outbound VNet integration.')
param apimSubnetName string = 'apim-subnet'
param apimSubnetPrefix string = '192.168.3.0/24'

@description('Address prefix for AzureBastionSubnet (minimum /26).')
param bastionSubnetPrefix string = '192.168.4.0/26'

@description('Address prefix for the jumpbox subnet.')
param jumpboxSubnetPrefix string = '192.168.6.0/24'

// ---------------------------------------------------------------------------
// APIM parameters
// ---------------------------------------------------------------------------
@description('SKU of the API Management service. StandardV2 / PremiumV2 support private endpoints.')
@allowed([
  'StandardV2'
  'PremiumV2'
])
param apimSku string = 'StandardV2'

@description('Capacity (scale units) of the API Management service.')
param apimCapacity int = 1

@description('Publisher email for the APIM service.')
param publisherEmail string = 'apim-admin@contoso.com'

@description('Publisher name for the APIM service.')
param publisherName string = 'AI Foundry'

@description('Name for the APIM gateway connection on the Foundry project (model accessed as <name>/<model>).')
param apimConnectionName string = 'apim-gateway'

@description('Azure OpenAI inference API version exposed through APIM.')
param inferenceApiVersion string = '2024-10-21'

// ---------------------------------------------------------------------------
// Cross-region OpenAI parameters
// ---------------------------------------------------------------------------
@description('Set to true to deploy a cross-region Azure OpenAI account exposed through APIM.')
param deployCrossRegionOpenAI bool = true

@description('Model name to deploy in the cross-region OpenAI account.')
param crossRegionModelName string = 'gpt-4o'

@description('Model version for the cross-region deployment.')
param crossRegionModelVersion string = '2024-11-20'

@description('Name for the cross-region APIM gateway connection on the Foundry project.')
param apimCrossRegionConnectionName string = 'apim-gateway-crossregion'

// ---------------------------------------------------------------------------
// Observability parameters
// ---------------------------------------------------------------------------
@description('Set to true to deploy Application Insights + Log Analytics and connect them to the Foundry project.')
param deployApplicationInsights bool = true

// ---------------------------------------------------------------------------
// Bastion / jumpbox parameters
// ---------------------------------------------------------------------------
@description('Set to true to deploy Azure Bastion and a Windows jump-box VM.')
param deployBastion bool = true

@description('Admin username for the jump-box VM.')
param jumpboxAdminUsername string = 'azureuser'

@description('Auto-approve the AI Search → AI Services shared private link via a deployment script. Default is false because Microsoft.Resources/deploymentScripts requires shared-key storage access, which is blocked by the `KeyBasedAuthenticationNotPermitted` tenant policy in some environments. When false, approve the connection from the notebook.')
param autoApproveSharedPrivateLink bool = false

@description('Admin password for the jump-box VM (required when deployBastion is true).')
@secure()
param jumpboxAdminPassword string = ''

@description('When true, run a first-boot bootstrap on the jump-box that installs Python 3.12, Azure CLI, Git, VS Code, PowerShell 7 and Windows Terminal via winget, then clones the AI-Gateway repo and installs Python + VS Code dependencies. Logs to C:\\bootstrap.log on the VM.')
param installDevTools bool = true

// ---------------------------------------------------------------------------
// Capability host name
// ---------------------------------------------------------------------------
@description('Name of the Foundry project capability host.')
param projectCapHost string = 'caphostproj'

// ---------------------------------------------------------------------------
// Computed names
// ---------------------------------------------------------------------------
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 4)
var accountName = toLower('${aiServicesName}${uniqueSuffix}')
var projectName = toLower('${foundryProjectName}${uniqueSuffix}')
var cosmosDBName = toLower('${aiServicesName}${uniqueSuffix}cosmosdb')
var aiSearchName = toLower('${aiServicesName}${uniqueSuffix}search')
var azureStorageName = toLower('${aiServicesName}${uniqueSuffix}storage')
var apiManagementServiceName = toLower('${aiServicesName}${uniqueSuffix}apim')
var appInsightsName = toLower('${aiServicesName}${uniqueSuffix}appinsights')
var crossRegionOpenAIName = toLower('${aiServicesName}${uniqueSuffix}openai${locationCrossRegion}')

// DNS zones to create / reuse (all in this resource group; values are empty so the module creates them)
var existingDnsZones = {
  'privatelink.services.ai.azure.com': ''
  'privatelink.openai.azure.com': ''
  'privatelink.cognitiveservices.azure.com': ''
  'privatelink.search.windows.net': ''
  #disable-next-line no-hardcoded-env-urls
  'privatelink.blob.core.windows.net': ''
  'privatelink.documents.azure.com': ''
  'privatelink.analysis.windows.net': ''
  'privatelink.azure-api.net': ''
}
var dnsZoneNames = [
  'privatelink.services.ai.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.search.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'privatelink.blob.core.windows.net'
  'privatelink.documents.azure.com'
  'privatelink.analysis.windows.net'
  'privatelink.azure-api.net'
]

// Load the APIM inbound policy from a sibling file
var apimPolicyXml = loadTextContent('policy.xml')

// ---------------------------------------------------------------------------
// Virtual Network
// ---------------------------------------------------------------------------
module vnet 'modules/network-agent-vnet.bicep' = {
  name: 'vnet-${uniqueSuffix}-deployment'
  params: {
    location: location
    vnetName: vnetName
    useExistingVnet: false
    agentSubnetName: agentSubnetName
    peSubnetName: peSubnetName
    mcpSubnetName: mcpSubnetName
    vnetAddressPrefix: vnetAddressPrefix
    agentSubnetPrefix: agentSubnetPrefix
    peSubnetPrefix: peSubnetPrefix
    mcpSubnetPrefix: mcpSubnetPrefix
  }
}

// APIM subnet (delegated to Microsoft.Web/serverFarms for StandardV2 VNet integration)
resource apimSubnetNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${vnetName}-${apimSubnetName}-nsg'
  location: location
}

module apimSubnet 'modules/subnet.bicep' = {
  name: 'apim-subnet-${uniqueSuffix}-deployment'
  params: {
    vnetName: vnet.outputs.virtualNetworkName
    subnetName: apimSubnetName
    addressPrefix: apimSubnetPrefix
    networkSecurityGroupId: apimSubnetNsg.id
    delegations: [
      {
        name: 'Microsoft.Web/serverFarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Foundry account + Application Insights
// ---------------------------------------------------------------------------
module aiAccount 'modules/ai-account-identity.bicep' = {
  name: '${accountName}-${uniqueSuffix}-deployment'
  params: {
    accountName: accountName
    location: location
    modelName: modelName
    modelFormat: modelFormat
    modelVersion: modelVersion
    modelSkuName: modelSkuName
    modelCapacity: modelCapacity
    agentSubnetId: vnet.outputs.agentSubnetId
  }
}

module applicationInsights 'modules/application-insights.bicep' = if (deployApplicationInsights) {
  name: 'appinsights-${uniqueSuffix}-deployment'
  params: {
    location: location
    accountName: aiAccount.outputs.accountName
    appInsightsName: appInsightsName
  }
}

// ---------------------------------------------------------------------------
// Validate / create dependent backend resources
// ---------------------------------------------------------------------------
module validateExistingResources 'modules/validate-existing-resources.bicep' = {
  name: 'validate-existing-${uniqueSuffix}-deployment'
  params: {
    aiSearchResourceId: ''
    azureStorageAccountResourceId: ''
    azureCosmosDBAccountResourceId: ''
    apiManagementResourceId: ''
    existingDnsZones: existingDnsZones
    dnsZoneNames: dnsZoneNames
  }
}

module aiDependencies 'modules/standard-dependent-resources.bicep' = {
  name: 'dependencies-${uniqueSuffix}-deployment'
  params: {
    location: location
    azureStorageName: azureStorageName
    aiSearchName: aiSearchName
    cosmosDBName: cosmosDBName
    aiSearchResourceId: ''
    aiSearchExists: validateExistingResources.outputs.aiSearchExists
    azureStorageAccountResourceId: ''
    azureStorageExists: validateExistingResources.outputs.azureStorageExists
    cosmosDBResourceId: ''
    cosmosDBExists: validateExistingResources.outputs.cosmosDBExists
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: aiDependencies.outputs.azureStorageName
}

resource aiSearch 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: aiDependencies.outputs.aiSearchName
}

resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: aiDependencies.outputs.cosmosDBName
}

// ---------------------------------------------------------------------------
// API Management
// ---------------------------------------------------------------------------
module apimDependencies 'modules/api-management.bicep' = {
  name: 'apim-${uniqueSuffix}-deployment'
  params: {
    location: location
    apiManagementName: apiManagementServiceName
    apiManagementSku: apimSku
    apiManagementCapacity: apimCapacity
    publisherEmail: publisherEmail
    publisherName: publisherName
    apimSubnetId: apimSubnet.outputs.subnetId
    apiManagementResourceId: ''
    apiManagementExists: false
  }
}

// ---------------------------------------------------------------------------
// Private endpoints + DNS
// ---------------------------------------------------------------------------
module privateEndpointAndDNS 'modules/private-endpoint-and-dns.bicep' = {
  name: 'private-endpoints-${uniqueSuffix}-deployment'
  params: {
    aiAccountName: aiAccount.outputs.accountName
    aiSearchName: aiDependencies.outputs.aiSearchName
    storageName: aiDependencies.outputs.azureStorageName
    cosmosDBName: aiDependencies.outputs.cosmosDBName
    fabricWorkspaceResourceId: ''
    apiManagementName: apimDependencies.outputs.apiManagementName
    vnetName: vnet.outputs.virtualNetworkName
    peSubnetName: vnet.outputs.peSubnetName
    suffix: uniqueSuffix
    existingDnsZones: existingDnsZones
  }
  dependsOn: [
    aiSearch
    storage
    cosmosDB
  ]
}

// ---------------------------------------------------------------------------
// Foundry project + role assignments
// ---------------------------------------------------------------------------
module aiProject 'modules/ai-project-identity.bicep' = {
  name: '${projectName}-${uniqueSuffix}-deployment'
  params: {
    projectName: projectName
    projectDescription: 'Foundry project for the foundry-e2e-private AI Gateway lab.'
    displayName: 'Foundry E2E Private'
    location: location
    aiSearchName: aiDependencies.outputs.aiSearchName
    aiSearchServiceResourceGroupName: aiDependencies.outputs.aiSearchServiceResourceGroupName
    aiSearchServiceSubscriptionId: aiDependencies.outputs.aiSearchServiceSubscriptionId
    cosmosDBName: aiDependencies.outputs.cosmosDBName
    cosmosDBSubscriptionId: aiDependencies.outputs.cosmosDBSubscriptionId
    cosmosDBResourceGroupName: aiDependencies.outputs.cosmosDBResourceGroupName
    azureStorageName: aiDependencies.outputs.azureStorageName
    azureStorageSubscriptionId: aiDependencies.outputs.azureStorageSubscriptionId
    azureStorageResourceGroupName: aiDependencies.outputs.azureStorageResourceGroupName
    accountName: aiAccount.outputs.accountName
  }
  dependsOn: [
    privateEndpointAndDNS
  ]
}

module formatProjectWorkspaceId 'modules/format-project-workspace-id.bicep' = {
  name: 'format-workspace-id-${uniqueSuffix}-deployment'
  params: {
    projectWorkspaceId: aiProject.outputs.projectWorkspaceId
  }
}

module storageAccountRoleAssignment 'modules/azure-storage-account-role-assignment.bicep' = {
  name: 'storage-ra-${uniqueSuffix}-deployment'
  params: {
    azureStorageName: aiDependencies.outputs.azureStorageName
    projectPrincipalId: aiProject.outputs.projectPrincipalId
  }
  dependsOn: [
    storage
    privateEndpointAndDNS
  ]
}

module cosmosAccountRoleAssignments 'modules/cosmosdb-account-role-assignment.bicep' = {
  name: 'cosmos-account-ra-${uniqueSuffix}-deployment'
  params: {
    cosmosDBName: aiDependencies.outputs.cosmosDBName
    projectPrincipalId: aiProject.outputs.projectPrincipalId
  }
  dependsOn: [
    cosmosDB
    privateEndpointAndDNS
  ]
}

module aiSearchRoleAssignments 'modules/ai-search-role-assignments.bicep' = {
  name: 'ai-search-ra-${uniqueSuffix}-deployment'
  params: {
    aiSearchName: aiDependencies.outputs.aiSearchName
    projectPrincipalId: aiProject.outputs.projectPrincipalId
  }
  dependsOn: [
    aiSearch
    privateEndpointAndDNS
  ]
}

module searchMiToStorageRoleAssignment 'modules/search-mi-to-storage-role-assignment.bicep' = {
  name: 'search-mi-storage-ra-${uniqueSuffix}-deployment'
  params: {
    azureStorageName: aiDependencies.outputs.azureStorageName
    searchServicePrincipalId: aiDependencies.outputs.aiSearchPrincipalId
  }
  dependsOn: [
    aiSearch
    storage
    privateEndpointAndDNS
  ]
}

module searchMiToOpenAIRoleAssignment 'modules/search-mi-to-openai-role-assignment.bicep' = {
  name: 'search-mi-openai-ra-${uniqueSuffix}-deployment'
  params: {
    accountName: aiAccount.outputs.accountName
    searchServicePrincipalId: aiDependencies.outputs.aiSearchPrincipalId
  }
  dependsOn: [
    aiSearch
    privateEndpointAndDNS
  ]
}

module searchToAiServicesSharedPrivateLink 'modules/search-shared-private-link-to-aiservices.bicep' = {
  name: 'search-spl-aiservices-${uniqueSuffix}-deployment'
  params: {
    searchServiceName: aiDependencies.outputs.aiSearchName
    aiServicesAccountName: aiAccount.outputs.accountName
  }
  dependsOn: [
    aiSearch
    privateEndpointAndDNS
    searchMiToOpenAIRoleAssignment
  ]
}

module splAutoApprove 'modules/spl-auto-approve.bicep' = if (autoApproveSharedPrivateLink) {
  name: 'spl-auto-approve-${uniqueSuffix}-deployment'
  params: {
    location: location
    aiServicesAccountName: aiAccount.outputs.accountName
    sharedPrivateLinkName: searchToAiServicesSharedPrivateLink.outputs.sharedPrivateLinkName
  }
}

module accountToSearchRoleAssignment 'modules/ai-account-to-search-role-assignment.bicep' = {
  name: 'account-search-ra-${uniqueSuffix}-deployment'
  params: {
    aiSearchName: aiDependencies.outputs.aiSearchName
    accountPrincipalId: aiAccount.outputs.accountPrincipalId
  }
  dependsOn: [
    aiSearch
    privateEndpointAndDNS
  ]
}

module accountToStorageRoleAssignment 'modules/ai-account-to-storage-role-assignment.bicep' = {
  name: 'account-storage-ra-${uniqueSuffix}-deployment'
  params: {
    azureStorageName: aiDependencies.outputs.azureStorageName
    accountPrincipalId: aiAccount.outputs.accountPrincipalId
  }
  dependsOn: [
    storage
    privateEndpointAndDNS
  ]
}

module addProjectCapabilityHost 'modules/add-project-capability-host.bicep' = {
  name: 'caphost-${uniqueSuffix}-deployment'
  params: {
    accountName: aiAccount.outputs.accountName
    projectName: aiProject.outputs.projectName
    cosmosDBConnection: aiProject.outputs.cosmosDBConnection
    azureStorageConnection: aiProject.outputs.azureStorageConnection
    aiSearchConnection: aiProject.outputs.aiSearchConnection
    projectCapHost: projectCapHost
  }
  dependsOn: [
    aiSearch
    storage
    cosmosDB
    privateEndpointAndDNS
    cosmosAccountRoleAssignments
    storageAccountRoleAssignment
    aiSearchRoleAssignments
  ]
}

module storageContainersRoleAssignment 'modules/blob-storage-container-role-assignments.bicep' = {
  name: 'storage-containers-ra-${uniqueSuffix}-deployment'
  params: {
    aiProjectPrincipalId: aiProject.outputs.projectPrincipalId
    storageName: aiDependencies.outputs.azureStorageName
    workspaceId: formatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
  }
  dependsOn: [
    addProjectCapabilityHost
  ]
}

module cosmosContainerRoleAssignments 'modules/cosmos-container-role-assignments.bicep' = {
  name: 'cosmos-containers-ra-${uniqueSuffix}-deployment'
  params: {
    cosmosAccountName: aiDependencies.outputs.cosmosDBName
    projectWorkspaceId: formatProjectWorkspaceId.outputs.projectWorkspaceIdGuid
    projectPrincipalId: aiProject.outputs.projectPrincipalId
  }
  dependsOn: [
    addProjectCapabilityHost
    storageContainersRoleAssignment
  ]
}

// ---------------------------------------------------------------------------
// APIM gateway connection on the project (model accessed as apim-gateway/<model>)
// ---------------------------------------------------------------------------
var defaultModelDeployments = [
  {
    name: modelName
    properties: {
      model: {
        name: modelName
        version: modelVersion
        format: modelFormat
      }
    }
  }
]

module apimGatewayConnection 'modules/apim-gateway-connection.bicep' = {
  name: 'apim-gateway-connection-${uniqueSuffix}-deployment'
  params: {
    accountName: aiAccount.outputs.accountName
    projectName: aiProject.outputs.projectName
    apimName: apimDependencies.outputs.apiManagementName
    aiServicesEndpoint: 'https://${aiAccount.outputs.accountName}.openai.azure.com'
    connectionName: apimConnectionName
    inferenceApiVersion: inferenceApiVersion
    modelDeployments: defaultModelDeployments
    policyXml: apimPolicyXml
  }
  dependsOn: [
    addProjectCapabilityHost
    privateEndpointAndDNS
  ]
}

// ---------------------------------------------------------------------------
// Cross-region OpenAI (optional)
// ---------------------------------------------------------------------------
module crossRegionOpenAI 'modules/cross-region-openai-connection.bicep' = if (deployCrossRegionOpenAI) {
  name: 'cross-region-openai-${uniqueSuffix}-deployment'
  params: {
    location: locationCrossRegion
    accountName: aiAccount.outputs.accountName
    projectName: aiProject.outputs.projectName
    openAIName: crossRegionOpenAIName
    modelName: crossRegionModelName
    modelVersion: crossRegionModelVersion
    apimName: apimDependencies.outputs.apiManagementName
    connectionName: apimCrossRegionConnectionName
    inferenceApiVersion: inferenceApiVersion
    vnetName: vnet.outputs.virtualNetworkName
    peSubnetName: vnet.outputs.peSubnetName
    policyXml: apimPolicyXml
  }
  dependsOn: [
    addProjectCapabilityHost
    apimGatewayConnection
    privateEndpointAndDNS
  ]
}

// ---------------------------------------------------------------------------
// Bastion + jumpbox (optional)
// ---------------------------------------------------------------------------
module bastionJumpbox 'modules/bastion-jumpbox.bicep' = if (deployBastion) {
  name: 'bastion-${uniqueSuffix}-deployment'
  params: {
    location: location
    vnetName: vnet.outputs.virtualNetworkName
    bastionSubnetPrefix: bastionSubnetPrefix
    jumpboxSubnetName: 'jumpbox-subnet'
    jumpboxSubnetPrefix: jumpboxSubnetPrefix
    bastionName: '${accountName}-bastion'
    vmName: '${uniqueSuffix}-jumpbox'
    adminUsername: jumpboxAdminUsername
    adminPassword: jumpboxAdminPassword
    installDevTools: installDevTools
  }
  // Serialize VNet subnet creation to avoid AnotherOperationInProgress errors:
  // the bastion module adds AzureBastionSubnet + jumpbox-subnet to the VNet
  // while other modules (apimSubnet, private endpoints) are also mutating it.
  dependsOn: [
    apimSubnet
    privateEndpointAndDNS
  ]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output resourceGroupName string = resourceGroup().name
output aiServicesName string = aiAccount.outputs.accountName
output aiProjectName string = aiProject.outputs.projectName
output aiProjectEndpoint string = 'https://${aiAccount.outputs.accountName}.services.ai.azure.com/api/projects/${aiProject.outputs.projectName}'

output apimServiceName string = apimDependencies.outputs.apiManagementName
output apimResourceId string = apimDependencies.outputs.apiManagementId
output apimGatewayUrl string = 'https://${apimDependencies.outputs.apiManagementName}.azure-api.net'

output apimGatewayConnectionName string = apimGatewayConnection.outputs.connectionName
#disable-next-line BCP318
output apimCrossRegionConnectionName string = deployCrossRegionOpenAI ? crossRegionOpenAI.outputs.connectionName : ''

#disable-next-line BCP318
output appInsightsConnectionString string = deployApplicationInsights ? applicationInsights.outputs.appInsightsConnectionString : ''
#disable-next-line BCP318
output logAnalyticsWorkspaceId string = deployApplicationInsights ? applicationInsights.outputs.logAnalyticsWorkspaceId : ''

output vnetName string = vnet.outputs.virtualNetworkName
#disable-next-line BCP318
output bastionName string = deployBastion ? bastionJumpbox.outputs.bastionName : ''
#disable-next-line BCP318
output jumpboxName string = deployBastion ? bastionJumpbox.outputs.vmName : ''

output aiSearchName string = aiDependencies.outputs.aiSearchName
output sharedPrivateLinkName string = searchToAiServicesSharedPrivateLink.outputs.sharedPrivateLinkName
