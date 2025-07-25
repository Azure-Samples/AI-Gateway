/**
 * @module cosmosdb
 * @description This module defines the Azure Cosmos DB resources using Bicep.
 * It includes configurations for creating and managing Cosmos DB accounts, databases, and containers.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Cosmos DB account')
param cosmosDbAccountName string

@description('The location of the Cosmos DB account. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The name of the database')
param databaseName string = 'mcpoauth'

@description('The name of the container for client registrations')
param containerName string = 'clientregistrations'

@description('Tags to apply to resources')
param tags object = {}

// ------------------
//    RESOURCES
// ------------------

// Create Cosmos DB account
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbAccountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Enabled'
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

// Create database
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosDbAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

// Create container for client registrations
resource clientRegistrationsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: database
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/clientId'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbAccountId string = cosmosDbAccount.id
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint
output databaseName string = database.name
output containerName string = clientRegistrationsContainer.name
output cosmosDbAccountResourceId string = cosmosDbAccount.id
