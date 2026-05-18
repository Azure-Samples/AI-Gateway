// Assigns the AI Search service's managed identity the Storage Blob Data Reader role
// on the Storage account. Required for knowledge source indexing from blob storage.

@description('Name of the Storage account')
param azureStorageName string

@description('Principal ID of the AI Search service managed identity')
param searchServicePrincipalId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: azureStorageName
  scope: resourceGroup()
}

// Storage Blob Data Reader: acdd72a7-3385-48ef-bd42-f606fba81ae7
resource storageBlobDataReader 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  scope: resourceGroup()
}

resource storageBlobDataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(searchServicePrincipalId, storageBlobDataReader.id, storageAccount.id)
  properties: {
    principalId: searchServicePrincipalId
    roleDefinitionId: storageBlobDataReader.id
    principalType: 'ServicePrincipal'
  }
}
