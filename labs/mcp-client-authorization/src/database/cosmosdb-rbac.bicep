/**
 * @module cosmosdb-rbac
 * @description This module assigns RBAC roles for Cosmos DB access
 */

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Cosmos DB account')
param cosmosDbAccountName string

@description('The principal ID to assign the role to')
param principalId string

// ------------------
//    RESOURCES
// ------------------

// Reference existing Cosmos DB account
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: cosmosDbAccountName
}

// Grant Cosmos DB Built-in Data Contributor role
// Role definition ID: 00000000-0000-0000-0000-000000000002
resource cosmosDbRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  name: guid(cosmosDbAccount.id, principalId, 'Cosmos DB Built-in Data Contributor')
  parent: cosmosDbAccount
  properties: {
    principalId: principalId
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    scope: cosmosDbAccount.id
  }
}
