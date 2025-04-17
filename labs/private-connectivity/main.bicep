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
param openAIAPIVersion string

// ------------------
//    VARIABLES
// ------------------

var virtualNetworkName = 'vnet-spoke'
var subnetAiServicesName = 'snet-aiservices'
var subnetApimName = 'snet-apim'
var subnetVmName = 'snet-vm'

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
module nsgApimModule '../../modules/network/v1/nsg.bicep' = {
  name: 'nsgApim'
  params: {
    nsgName: 'nsg-apim'
    location: resourceGroup().location
  }
}

// VNET and Subnets
module vnetModule '../../modules/network/v1/vnet.bicep' = {
  name: 'vnetModule'
  params: {
    virtualNetworkName: virtualNetworkName
    addressPrefixes: ['10.0.0.0/16']
    subnets: [
      {
        name: subnetAiServicesName
        addressPrefix: '10.0.0.0/24'
      }
      {
        name: subnetApimName
        addressPrefix: '10.0.1.0/24'
        networkSecurityGroupId: nsgApimModule.outputs.id
        delegation:'Microsoft.Web/serverFarms'
      }
      {
        name: subnetVmName
        addressPrefix: '10.0.2.0/24'
      }
    ]
  }
}

// API Management
module apimModule '../../modules/apim/v2/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    subnetId: '${vnetModule.outputs.id}/subnets/${subnetApimName}' // resourceId('Microsoft.Network/virtualNetworks/subnets', vnetModule.outputs.subnets[1].id) // vnetModule.outputs.subnets[1].id // 
  }
}

// Cognitive Services and LLM models
module openAIModule '../../modules/cognitive-services/v3/openai.bicep' = {
  name: 'openAIModule'
  params: {
    openAIConfig: openAIConfig
    openAIDeploymentName: openAIDeploymentName
    openAIModelName: openAIModelName
    openAIModelVersion: openAIModelVersion
    openAIModelSKU: openAIModelSKU
    apimPrincipalId: apimModule.outputs.principalId
    enablePrivateEndpoint: true
    vnetId: vnetModule.outputs.id
    subnetId: '${vnetModule.outputs.id}/subnets/${subnetAiServicesName}' // vnetModule.outputs.subnets[0].id
  }
}

// APIM OpenAI API
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
    backendHostName: replace(apimModule.outputs.gatewayUrl, 'https://', '')
    privateLinkBackendId: apimModule.outputs.id
  }
}

// Bastion Host
module bastionModule '../../modules/bastion/v1/bastion.bicep' = {
  name: 'bastionModule'
  params: {
    bastionHostName: 'bastion-host'
    vnetId: vnetModule.outputs.id
    location: resourceGroup().location
  }
}

// Jumpbox VM
module vmModule '../../modules/virtual-machine/vm.bicep' = {
  name: 'vmModule'
  params: {
    vmName: 'vm-win11'
    location: resourceGroup().location
    vmSize: 'Standard_D2ads_v5'
    subnetVmId: '${vnetModule.outputs.id}/subnets/${subnetVmName}' // vnetModule.outputs.subnets[2].id
    vmAdminUsername: 'azureuser'
    vmAdminPassword: '@Aa123456789' // should be secured in real world
  }
}

// ------------------
//    MARK: OUTPUTS
// ------------------
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = openAIAPIModule.outputs.subscriptionPrimaryKey
output frontDoorEndpointHostName string = frontDoorModule.outputs.frontDoorEndpointHostName
