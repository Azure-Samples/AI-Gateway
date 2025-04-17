@description('Name of the virtual network to create')
param virtualNetworkName string = 'vnet-spoke'

@description('The name of the API Management instance. Defaults to "apim-<resourceSuffix>".')
param subnetAiServicesName string = 'snet-aiservices'
param subnetApimName string = 'snet-apim'
param subnetVmName string = 'snet-vm'

// NSG for APIM Subnet
resource nsgApim 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-apim'
  location: resourceGroup().location
}

// 1. VNET and Subnets
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetAiServicesName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: subnetApimName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsgApim.id
          }
          delegations: [
            {
              name: 'Microsoft.Web/serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: subnetVmName
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }

  resource subnetAiServices 'subnets' existing = {
    name: subnetAiServicesName
  }

  resource subnetApim 'subnets' existing = {
    name: subnetApimName
  }

  resource subnetVm 'subnets' existing = {
    name: subnetVmName
  }
}

output subnetAiServicesResourceId string = virtualNetwork::subnetAiServices.id
output subnetApimResourceId string = virtualNetwork::subnetApim.id
