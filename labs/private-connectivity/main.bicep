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
  // properties: {
  //   securityRules: [
  //     {
  //       name: 'Allow-APIM'
  //       properties: {
  //         protocol: 'Tcp'
  //         sourcePortRange: '*'
  //         destinationPortRange: '443'
  //         sourceAddressPrefix: '*'
  //         destinationAddressPrefix: '*'
  //         access: 'Allow'
  //         priority: 1000
  //         direction: 'Inbound'
  //       }
  //     }
  //   ]
  // }
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
    ]
  }

  resource subnetAiServices 'subnets' existing = {
    name: subnetAiServicesName
  }

  resource subnetApim 'subnets' existing = {
    name: subnetApimName
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

// ------------------
//    MARK: OUTPUTS
// ------------------
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = openAIAPIModule.outputs.subscriptionPrimaryKey
