@description('Name of the virtual network to create')
param virtualNetworkName string = 'vnet-spoke'

@description('The CIDR range of the virtual network')
param addressPrefixes array = ['10.0.0.0/16'] 

@description('Array of subnets to create within the virtual network')
param subnets subnetType[]?

// 1. VNET and Subnets
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [ for (subnet, index) in (subnets ?? []): {
      name: subnet.?name
      properties: {
        addressPrefix: subnet.?addressPrefix
        networkSecurityGroup: !empty(subnet.?networkSecurityGroupId)
        ? {
            id: subnet.?networkSecurityGroupId
          }
        : null
        delegations: !empty(subnet.?delegation)
        ? [
            {
              name: subnet.?delegation
              properties: {
                serviceName: subnet.?delegation
              }
            }
          ]
        : []
      }
    }]
  }
}

type subnetType = {
  @description('Required. The Name of the subnet resource.')
  name: string

  @description('Conditional. List of address prefixes for the subnet. Required if `addressPrefix` is empty.')
  addressPrefix: string

  @description('Optional. The resource ID of the network security group to assign to the subnet.')
  networkSecurityGroupId: string?

  @description('Optional. The delegation to enable on the subnet.')
  delegation: string?
}

output id string = virtualNetwork.id
output subnets array = [ for (subnet, index) in (subnets ?? []): {
  name: subnet.?name
  id: virtualNetwork.properties.subnets[index].id
}]
