@description('Name of Azure Bastion resource')
param bastionHostName string = 'bastion-host'

@description('Virtual Network ID for the Bastion host')
param vnetId string = ''

@description('Azure region for Bastion and virtual network')
param location string = resourceGroup().location

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionHostName
  location: location
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: vnetId
    }
  }
}
