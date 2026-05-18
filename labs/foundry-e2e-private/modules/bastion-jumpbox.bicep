/*
Bastion and Jump Box Module
----------------------------
Creates Azure Bastion + a Windows VM jump box for accessing private resources
via the Azure portal. This enables debugging and portal access without VPN.

Requirements:
- AzureBastionSubnet (/26 minimum)
- Standard SKU public IP for Bastion
- VM in a subnet that can reach private endpoints
*/

@description('Azure region for the deployment')
param location string

@description('VNet name to deploy into')
param vnetName string

@description('Address prefix for AzureBastionSubnet (minimum /26)')
param bastionSubnetPrefix string = '192.168.4.0/26'

@description('Name for the jump box subnet')
param jumpboxSubnetName string = 'jumpbox-subnet'

@description('Address prefix for the jump box subnet')
param jumpboxSubnetPrefix string = '192.168.6.0/24'

@description('Name for the Bastion host')
param bastionName string = 'bastion'

@description('Name for the jump box VM')
param vmName string = 'jumpbox'

@description('VM size')
param vmSize string = 'Standard_B2s_v2'

@description('Admin username for the VM')
param adminUsername string = 'azureuser'

@description('Admin password for the VM')
@secure()
param adminPassword string

@description('When true, run a first-boot bootstrap script that installs Python 3.12, Azure CLI, Git, VS Code, PowerShell 7 and Windows Terminal via winget, then clones the AI-Gateway repo and installs Python + VS Code dependencies. Logs to C:\\bootstrap.log on the VM.')
param installDevTools bool = true

@description('APIM gateway base URL baked into the desktop test scripts (e.g. https://<apim>.azure-api.net). Used by callers that talk to APIM directly with a subscription key.')
param apimGatewayUrl string = ''

@description('API version sent to APIM by the desktop test scripts (matches the imported Azure OpenAI inference spec).')
param inferenceApiVersion string = '2024-10-21'

@description('APIM API path for the primary Azure OpenAI API (e.g. openai). Combined with apimGatewayUrl to form the test base URL.')
param primaryApiPath string = ''

@description('Model deployment name on the primary Foundry account (e.g. gpt-4o-mini). Used as the OpenAI "model" parameter in the primary test script.')
param primaryModelDeployment string = ''

@description('APIM subscription key (primary) scoped to the primary Azure OpenAI API. Baked into the primary desktop test script as a protected run-command parameter.')
@secure()
param primarySubscriptionKey string = ''

@description('APIM API path for the cross-region Azure OpenAI API (e.g. openai-eastus2). Empty disables the cross-region desktop script.')
param crossRegionApiPath string = ''

@description('Model deployment name on the cross-region OpenAI account (e.g. gpt-4o). Used as the OpenAI "model" parameter in the cross-region test script.')
param crossRegionModelDeployment string = ''

@description('APIM subscription key (primary) scoped to the cross-region Azure OpenAI API.')
@secure()
param crossRegionSubscriptionKey string = ''

// ---- NAT Gateway for outbound internet ----
resource natGatewayPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${vmName}-nat-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: '${vmName}-nat-gw'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: natGatewayPip.id
      }
    ]
  }
}

// ---- Bastion Subnet ----
resource bastionVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: bastionVnet
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: bastionSubnetPrefix
  }
}

// ---- Bastion Public IP ----
resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${bastionName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ---- Bastion Host ----
resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          subnet: {
            id: bastionSubnet.id
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

// ---- Jump Box VM NIC ----
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

// Dedicated subnet for the jump box VM with NAT gateway for outbound internet
resource jumpboxSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: jumpboxSubnetName
  parent: existingVnet
  properties: {
    addressPrefix: jumpboxSubnetPrefix
    natGateway: {
      id: natGateway.id
    }
  }
  dependsOn: [
    bastionSubnet
  ]
}

resource vmNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: jumpboxSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// ---- Jump Box VM ----
resource jumpboxVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
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
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }
  }
}

output bastionName string = bastionHost.name
output vmName string = jumpboxVm.name
output vmPrivateIp string = vmNic.properties.ipConfigurations[0].properties.privateIPAddress

// ---- Bootstrap dev tooling on first boot ----
// Uses VM Run Command (managed) so the PowerShell script can be passed inline
// without needing a storage account or base64 wrapping. The script is
// idempotent and writes a transcript to C:\bootstrap.log.
resource jumpboxBootstrap 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = if (installDevTools) {
  parent: jumpboxVm
  name: 'install-dev-tools'
  location: location
  properties: {
    source: {
      script: loadTextContent('jumpbox-bootstrap.ps1')
    }
    parameters: [
      {
        name: 'ApimGatewayUrl'
        value: apimGatewayUrl
      }
      {
        name: 'InferenceApiVersion'
        value: inferenceApiVersion
      }
      {
        name: 'PrimaryApiPath'
        value: primaryApiPath
      }
      {
        name: 'PrimaryModelDeployment'
        value: primaryModelDeployment
      }
      {
        name: 'CrossRegionApiPath'
        value: crossRegionApiPath
      }
      {
        name: 'CrossRegionModelDeployment'
        value: crossRegionModelDeployment
      }
    ]
    protectedParameters: [
      {
        name: 'PrimarySubscriptionKey'
        value: primarySubscriptionKey
      }
      {
        name: 'CrossRegionSubscriptionKey'
        value: crossRegionSubscriptionKey
      }
    ]
    timeoutInSeconds: 1800
    treatFailureAsDeploymentFailure: false
  }
}
