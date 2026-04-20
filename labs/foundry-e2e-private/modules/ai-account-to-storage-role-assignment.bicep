// Assigns the AI Services account's managed identity the Storage Blob Data Contributor role
// on the Storage account. Enables the AI Services account to read and write blob data.

@description('Name of the Storage account')
param azureStorageName string

@description('Principal ID of the AI Services account managed identity')
param accountPrincipalId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: azureStorageName
  scope: resourceGroup()
}

// Storage Blob Data Contributor: ba92f5b4-2d11-453d-a403-e96b0029c9fe
resource storageBlobDataContributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: resourceGroup()
}

resource storageBlobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(accountPrincipalId, storageBlobDataContributor.id, storageAccount.id)
  properties: {
    principalId: accountPrincipalId
    roleDefinitionId: storageBlobDataContributor.id
    principalType: 'ServicePrincipal'
  }
}
