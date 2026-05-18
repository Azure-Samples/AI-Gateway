param cosmosDBConnection string 
param azureStorageConnection string 
param aiSearchConnection string
param projectName string
param accountName string
param projectCapHost string

var threadConnections = ['${cosmosDBConnection}']
var storageConnections = ['${azureStorageConnection}']
var vectorStoreConnections = ['${aiSearchConnection}']


resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
   name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  name: projectName
  parent: account
}

// The Foundry control plane auto-creates the account-level capability host with the
// name '<accountName>@aml_aiagentservice' when networkInjections are configured on
// the account. We reference it as 'existing' so the project-level capability host
// can declare a dependency on it. Trying to create our own account capability host
// either times out or conflicts with the auto-created one.
resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview' existing = {
  name: '${accountName}@aml_aiagentservice'
  parent: account
}

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  name: projectCapHost
  parent: project
  properties: {
    #disable-next-line BCP037
    capabilityHostKind: 'Agents'
    vectorStoreConnections: vectorStoreConnections
    storageConnections: storageConnections
    threadStorageConnections: threadConnections
  }
  dependsOn: [
    accountCapabilityHost
  ]
}

output projectCapHost string = projectCapabilityHost.name
