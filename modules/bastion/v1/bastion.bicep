@description('Name of Azure Bastion resource')
param bastionHostName string

@description('Subnet ID for the Bastion host')
param subnetId string = ''

@description('Azure region for Bastion and virtual network')
param location string = resourceGroup().location

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'pip-${bastionHostName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: bastionHostName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}
