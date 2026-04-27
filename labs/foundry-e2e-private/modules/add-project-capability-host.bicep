param cosmosDBConnection string 
param azureStorageConnection string 
param aiSearchConnection string
param projectName string
param accountName string
param projectCapHost string
param accountCapHost string = 'caphostacct'

@description('Subnet ARM ID that matches the agent subnet recorded on the Foundry account networkInjections. Required for the account-level capability host when networkInjections are configured.')
param agentSubnetId string = ''

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

// The account-level capability host must exist (and be in 'Succeeded' state) before
// the project-level capability host can be created. It is NOT auto-created when
// networkInjections are configured on the account, so we create it explicitly here
// with empty connections (project-level host carries the actual connections).
// When networkInjections are configured on the account, the customerSubnet property
// on the capability host must match the subnetArmId recorded on the account, otherwise
// the platform rejects the create with "The customerSubnet property must match the
// subnet recorded on the Foundry account."
resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview' = {
  name: accountCapHost
  parent: account
  properties: empty(agentSubnetId) ? {
    #disable-next-line BCP037
    capabilityHostKind: 'Agents'
  } : {
    #disable-next-line BCP037
    capabilityHostKind: 'Agents'
    #disable-next-line BCP037
    customerSubnet: agentSubnetId
  }
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
