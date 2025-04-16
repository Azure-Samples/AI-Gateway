// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apimSku string
param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string
param openAIModelSKU string
// param openAIModelCapacity int
param openAIAPIVersion string
var virtualNetworkName = 'vnet-spoke'
var subnetAiServicesName = 'snet-aiservices'
var subnetApimName = 'snet-apim'
var subnetBastionName = 'AzureBastionSubnet'
var subnetVmName = 'snet-vm'
// ------------------
//    VARIABLES
// ------------------

// Account for all placeholders in the polixy.xml file.
var policyXml = loadTextContent('policy.xml')
var updatedPolicyXml = replace(
  policyXml,
  '{backend-id}',
  (length(openAIConfig) > 1) ? 'openai-backend-pool' : openAIConfig[0].name
)

// ------------------
//    RESOURCES
// ------------------

// NSG for APIM Subnet
resource nsgApim 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-apim'
  location: resourceGroup().location
}

// 1. VNET and Subnet
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
      {
        name: subnetBastionName
        properties: {
          addressPrefix: '10.0.3.0/24'
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

  resource subnetBastion 'subnets' existing = {
    name: subnetBastionName
  }

  resource subnetVm 'subnets' existing = {
    name: subnetVmName
  }
}

output subnetAiServicesResourceId string = virtualNetwork::subnetAiServices.id
output subnetApimResourceId string = virtualNetwork::subnetApim.id

// 1. API Management
module apimModule '../../modules/apim/v2/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    subnetId: virtualNetwork::subnetApim.id
  }
}

// 2. Cognitive Services
module openAIModule '../../modules/cognitive-services/v3/openai.bicep' = {
  name: 'openAIModule'
  params: {
    openAIConfig: openAIConfig
    openAIDeploymentName: openAIDeploymentName
    openAIModelName: openAIModelName
    openAIModelVersion: openAIModelVersion
    openAIModelSKU: openAIModelSKU
    // openAIModelCapacity: openAIModelCapacity
    apimPrincipalId: apimModule.outputs.principalId
    enablePrivateEndpoint: true
    vnetId: virtualNetwork.id
    subnetId: virtualNetwork::subnetAiServices.id
  }
}



// 3. APIM OpenAI API
module openAIAPIModule '../../modules/apim/v1/openai-api.bicep' = {
  name: 'openAIAPIModule'
  params: {
    policyXml: updatedPolicyXml
    openAIConfig: openAIModule.outputs.extendedOpenAIConfig
    openAIAPIVersion: openAIAPIVersion
  }
}

// Front Door
module frontDoorModule '../../modules/frontdoor/v1/frontdoor.bicep' = {
  name: 'frontDoorModule'
  params: {
    hostName: replace(apimModule.outputs.gatewayUrl, 'https://', '')
    privateLinkBackendId: apimModule.outputs.id
  }
}

// Bastion Host
module bastionModule '../../modules/bastion/v1/bastion.bicep' = {
  name: 'bastionModule'
  params: {
    bastionHostName: 'bastion-host'
    subnetId: virtualNetwork::subnetBastion.id
    location: resourceGroup().location
  }
}

// VM
module vmModule '../../modules/virtual-machine/vm.bicep' = {
  name: 'vmModule'
  params: {
    vmName: 'vm-win11'
    location: resourceGroup().location
    vmSize: 'Standard_D2ads_v5'
    subnetVmId: virtualNetwork::subnetVm.id
    vmAdminUsername: 'azureuser'
    vmAdminPassword: '@Aa123456789'
  }
}

// ------------------
//    MARK: OUTPUTS
// ------------------
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = openAIAPIModule.outputs.subscriptionPrimaryKey
output frontDoorEndpointHostName string = frontDoorModule.outputs.frontDoorEndpointHostName
