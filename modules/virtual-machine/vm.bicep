// ------------------
//    PARAMETERS
// ------------------

@description('Name of the virtual machine')
param vmName string = 'vm-jumpbox'

@description('The Id of the Subnet to be used for the VM')
param subnetVmId string = ''

@description('The size of the virtual machine')
param vmSize string = 'Standard_D2ads_v5'

@description('The location of the virtual machine')
param location string = resourceGroup().location

@description('The admin username for the virtual machine')
param vmAdminUsername string = 'azureuser'

@secure()
@description('The admin password for the virtual machine')
param vmAdminPassword string = ''

// ------------------
//    RESOURCES
// ------------------

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-${vmName}'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetVmId
          }
        }
      }
    ]
  } 
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' =  {
  name: vmName
  location: location
  properties: {
    priority: 'Spot'
    evictionPolicy: 'Deallocate'
    billingProfile: {
      maxPrice: -1
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}
