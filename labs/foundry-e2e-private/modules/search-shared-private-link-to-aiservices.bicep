// Creates a Shared Private Link from the Azure AI Search service to the AI Services
// account (groupId: openai_account).
//
// Why: First-class indexer skills (e.g., AzureOpenAIEmbeddingSkill) automatically
// route through this SPL when the resourceUri matches. With Foundry's
// publicNetworkAccess=Disabled, the SPL is the only path for AI Search to reach
// the Foundry / OpenAI endpoints.
//
// Note: The created Private Endpoint Connection on the AI Services side starts
// in Pending state. The deploying lab approves it as a post-deployment step from
// the notebook using `az network private-endpoint-connection approve` (see the
// main notebook). This avoids `Microsoft.Resources/deploymentScripts`, which can
// be blocked in tenants that disallow shared-key access on storage accounts.

@description('Name of the Azure AI Search service that will own the SPL')
param searchServiceName string

@description('Name of the AI Services account being privately linked')
param aiServicesAccountName string

@description('Name of the SPL resource on the Search service')
param sharedPrivateLinkName string = 'search-to-aiservices-openai'

@description('Group id for the shared private link target. For AI Services accounts (kind=AIServices) used as Azure OpenAI, use openai_account.')
param groupId string = 'openai_account'

resource searchService 'Microsoft.Search/searchServices@2025-05-01' existing = {
  name: searchServiceName
}

resource aiServicesAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: aiServicesAccountName
}

resource sharedPrivateLink 'Microsoft.Search/searchServices/sharedPrivateLinkResources@2025-05-01' = {
  parent: searchService
  name: sharedPrivateLinkName
  properties: {
    privateLinkResourceId: aiServicesAccount.id
    groupId: groupId
    requestMessage: 'Azure AI Search indexer skill access to AI Services'
  }
}

output sharedPrivateLinkResourceId string = sharedPrivateLink.id
output sharedPrivateLinkName string = sharedPrivateLink.name
output aiServicesAccountId string = aiServicesAccount.id
output sharedPrivateLinkStatus string = sharedPrivateLink.properties.status
