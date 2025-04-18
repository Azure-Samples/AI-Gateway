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

var suffix = uniqueString(subscription().id, resourceGroup().id)
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
var azureRoles = loadJsonContent('../../modules/azure-roles.json')
var cognitiveServicesOpenAIUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)

var privateDnsZoneNamesAiServices = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
]

// ------------------
//    RESOURCES
// ------------------

// NSG for APIM Subnet
resource nsgApim 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-apim'
  location: resourceGroup().location
}

// VNET and Subnets
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
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
          networkSecurityGroup: nsgApim
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

// API Management

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: 'apim-${suffix}'
  location: resourceGroup().location
  sku: {
    name: apimSku
    capacity: 1
  }
  properties: {
    publisherEmail: 'noreply@microsoft.com'
    publisherName: 'Microsoft'
    virtualNetworkType  : 'External' // "Internal" # Setting up 'Internal' Internal Virtual Network Type is not supported for Sku Type 'StandardV2'.
    publicNetworkAccess : 'Enabled'  // "Disabled" # Blocking all public network access by setting property `publicNetworkAccess` of API Management service is not enabled during service creation.
    virtualNetworkConfiguration : {
      subnetResourceId: virtualNetwork::subnetApim.id
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// // Create a logger only if we have an App Insights ID and instrumentation key.
// resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (!empty(appInsightsId) && !empty(appInsightsInstrumentationKey)) {
//   name: 'apim-logger'
//   parent: apimService
//   properties: {
//     credentials: {
//       instrumentationKey: appInsightsInstrumentationKey
//     }
//     description: apimLoggerDescription
//     isBuffered: false
//     loggerType: 'applicationInsights'
//     resourceId: appInsightsId
//   }
// }
// module apimModule '../../modules/apim/v2/apim.bicep' = {
//   name: 'apimModule'
//   params: {
//     apimSku: apimSku
//     subnetId: '${vnetModule.outputs.id}/subnets/${subnetApimName}' // resourceId('Microsoft.Network/virtualNetworks/subnets', vnetModule.outputs.subnets[1].id) // vnetModule.outputs.subnets[1].id // 
//   }
// }

// Cognitive Services and LLM models
module openAIModule '../../modules/cognitive-services/v3/openai.bicep' = {
  name: 'openAIModule'
  params: {
    openAIConfig: openAIConfig
    openAIDeploymentName: openAIDeploymentName
    openAIModelName: openAIModelName
    openAIModelVersion: openAIModelVersion
    openAIModelSKU: openAIModelSKU
    apimPrincipalId: apimService.identity.principalId
    enablePrivateEndpoint: true
    vnetId: virtualNetwork.id
    subnetId: subnetAiServicesName
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
    vnetId: virtualNetwork.id
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
    subnetVmId: virtualNetwork::subnetVm.id
    vmAdminUsername: 'azureuser'
    vmAdminPassword: '@Aa123456789' // should be secured in real world
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: 'log-alanalytics-${suffix}'
  location: resourceGroup().location
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

// ------------------
//    MARK: OUTPUTS
// ------------------
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptionKey string = openAIAPIModule.outputs.subscriptionPrimaryKey
output frontDoorEndpointHostName string = frontDoorModule.outputs.frontDoorEndpointHostName
