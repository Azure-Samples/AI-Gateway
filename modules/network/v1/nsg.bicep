// ------------------
//    PARAMETERS
// ------------------

@description('Name of the NSG')
param nsgName string = 'nsg-apim'

@description('Location of the NSG')
param location string = resourceGroup().location

// ------------------
//    RESOURCES
// ------------------

// NSG for Subnet
resource nsgApim 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
}

output id string = nsgApim.id
