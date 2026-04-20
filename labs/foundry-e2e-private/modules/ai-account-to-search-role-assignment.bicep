// Assigns the AI Services account's managed identity roles on the AI Search service.
// Enables the AI Services account to manage search indexes and data.

@description('Name of the AI Search resource')
param aiSearchName string

@description('Principal ID of the AI Services account managed identity')
param accountPrincipalId string

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
  scope: resourceGroup()
}

// Search Index Data Contributor: 8ebe5a00-799e-43f5-93ac-243d3dce84a7
resource searchIndexDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  scope: resourceGroup()
}

resource searchIndexDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(accountPrincipalId, searchIndexDataContributorRole.id, searchService.id)
  properties: {
    principalId: accountPrincipalId
    roleDefinitionId: searchIndexDataContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

// Search Service Contributor: 7ca78c08-252a-4471-8644-bb5ff32d4ba0
resource searchServiceContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  scope: resourceGroup()
}

resource searchServiceContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(accountPrincipalId, searchServiceContributorRole.id, searchService.id)
  properties: {
    principalId: accountPrincipalId
    roleDefinitionId: searchServiceContributorRole.id
    principalType: 'ServicePrincipal'
  }
}
