// Assigns the AI Search service's managed identity the Cognitive Services OpenAI User role
// on the AI Services account. Required for knowledge source indexing that uses
// embedding models (e.g., text-embedding-3-small) and chat completion models.

@description('Name of the AI Services account')
param accountName string

@description('Principal ID of the AI Search service managed identity')
param searchServicePrincipalId string

resource aiAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
  scope: resourceGroup()
}

// Cognitive Services OpenAI User: 5e0bd9bd-7b93-4f28-af87-19fc36ad61bd
resource cognitiveServicesOpenAIUser 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  scope: resourceGroup()
}

resource cognitiveServicesOpenAIUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiAccount
  name: guid(searchServicePrincipalId, cognitiveServicesOpenAIUser.id, aiAccount.id)
  properties: {
    principalId: searchServicePrincipalId
    roleDefinitionId: cognitiveServicesOpenAIUser.id
    principalType: 'ServicePrincipal'
  }
}
