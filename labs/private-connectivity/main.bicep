// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apimSku string
param openAIConfig array = []
param openAIModelName string
param openAIModelVersion string
param openAIDeploymentName string

@description('Azure OpenAI Sku')
@allowed([
  'S0'
])
param openAISku string = 'S0'

@description('The relative path of the APIM API for OpenAI API')
param openAIAPIPath string = 'openai'

@description('The display name of the APIM API for OpenAI API')
param openAIAPIDisplayName string = 'OpenAI'

@description('The description of the APIM API for OpenAI API')
param openAIAPIDescription string = 'Azure OpenAI API inferencing API'

@description('Full URL for the OpenAI API spec')
param openAIAPISpecURL string = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json'

@description('The name of the APIM Subscription for OpenAI API')
param openAISubscriptionName string = 'openai-subscription'

@description('The description of the APIM Subscription for OpenAI API')
param openAISubscriptionDescription string = 'OpenAI Subscription'

@description('The name of the OpenAI backend pool')
param openAIBackendPoolName string = 'openai-backend-pool'

@description('The description of the OpenAI backend pool')
param openAIBackendPoolDescription string = 'Load balancer for multiple OpenAI endpoints'

@description('The name of the APIM API for OpenAI API')
param openAIAPIName string = 'openai'

@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorEndpointName string = 'afd-${uniqueString(resourceGroup().id)}'

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Premium_AzureFrontDoor'

@description('Name of Azure Bastion resource')
param bastionHostName string = 'bastion-host'

@description('Name of the virtual machine')
param vmName string = 'vm-jumpbox'

@description('The size of the virtual machine')
param vmSize string = 'Standard_D2ads_v5'

@description('The admin username for the virtual machine')
param vmAdminUsername string = 'azureuser'

@secure()
@description('The admin password for the virtual machine')
param vmAdminPassword string = '@Aa123456789' // should be secured in real world

// ------------------
//    VARIABLES
// ------------------

var suffix = uniqueString(subscription().id, resourceGroup().id)
var virtualNetworkName = 'vnet-spoke'
var subnetAiServicesName = 'snet-aiservices'
var subnetApimName = 'snet-apim'
var subnetVmName = 'snet-vm'

var frontDoorProfileName = 'FrontDoor'
var frontDoorOriginGroupName = 'OriginGroup'
var frontDoorOriginName = 'FrontDoorOrigin'
var frontDoorRouteName = 'FrontDoorRoute'

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

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = [
  for config in openAIConfig: if(length(openAIConfig) > 0) {
  name: '${config.name}-${suffix}'
  location: config.location
  sku: {
    name: openAISku
  }
  kind: 'AIServices'
  properties: {
    customSubDomainName: toLower('${config.name}-${suffix}')
    publicNetworkAccess: 'Disabled'
    apiProperties: {
      statisticsEnabled: false
    }
  }
}]

// // https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings
// resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0 && lawId != '') {
//   name: '${cognitiveServices[i].name}-diagnostics'
//   scope: cognitiveServices[i]
//   properties: {
//     workspaceId: lawId != '' ? lawId : null
//     logs: []
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//       }
//     ]
//   }
// }]

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [
  for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: openAIDeploymentName
  parent: cognitiveServices[i]
  properties: {
    model: {
      format: 'OpenAI'
      name: openAIModelName
      version: openAIModelVersion
    }
  }
  sku: {
      name: 'Standard'
      capacity: config.capacity
  }
}]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  scope: cognitiveServices[i]
  name: guid(subscription().id, resourceGroup().id, config.name, cognitiveServicesOpenAIUserRoleDefinitionID)
    properties: {
        roleDefinitionId: cognitiveServicesOpenAIUserRoleDefinitionID
        principalId: apimService.identity.principalId
        principalType: 'ServicePrincipal'
    }
}]

// Create private endpoint if enabled
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: '${config.name}-${suffix}-privateEndpoint'
  location: resourceGroup().location
  properties: {
    customNetworkInterfaceName: '${config.name}-${suffix}-nic'
    subnet: {
      id: virtualNetwork::subnetAiServices.id    
    }
    privateLinkServiceConnections: [
      {
        name: '${config.name}-${suffix}-privateLinkServiceConnection'
        properties: {
          privateLinkServiceId: cognitiveServices[i].id
          groupIds: ['account']
        }
      }
    ]
  }
}]

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [for (privateDnsZoneName, i) in privateDnsZoneNamesAiServices: if(length(privateDnsZoneNamesAiServices) > 0) {
  name: privateDnsZoneName
  location: 'global'
}]

// link private DNS zone to the virtual network
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (privateDnsZoneName, i) in privateDnsZoneNamesAiServices: if(length(privateDnsZoneNamesAiServices) > 0) {
  name: '${privateDnsZoneName}-link'
  location: 'global'
  parent: privateDnsZone[i]
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}]

// privateDnsZoneGroups for private endpoints
resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = [for (privateDnsZoneName, i) in privateDnsZoneNamesAiServices: if(length(privateDnsZoneNamesAiServices) > 0) {
  name: '${privateDnsZoneName}-dnsZoneGroup'
  parent: privateEndpoint[i]
  properties: {
    privateDnsZoneConfigs: [
      for (privateDnsZoneName, j) in privateDnsZoneNamesAiServices: {
        name: 'config${j}'
        properties: {
          privateDnsZoneId: privateDnsZone[j].id
        }
      }
    ]
  }
}]

// // Cognitive Services and LLM models
// module openAIModule '../../modules/cognitive-services/v3/openai.bicep' = {
//   name: 'openAIModule'
//   params: {
//     openAIConfig: openAIConfig
//     openAIDeploymentName: openAIDeploymentName
//     openAIModelName: openAIModelName
//     openAIModelVersion: openAIModelVersion
//     openAIModelSKU: openAIModelSKU
//     apimPrincipalId: apimService.identity.principalId
//     enablePrivateEndpoint: true
//     vnetId: virtualNetwork.id
//     subnetId: subnetAiServicesName
//   }
// }

// API Management Service
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

resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: openAIAPIName
  parent: apimService
  properties: {
    apiType: 'http'
    description: openAIAPIDescription
    displayName: openAIAPIDisplayName
    format: 'openapi-link'
    path: openAIAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: openAIAPISpecURL
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: updatedPolicyXml // loadTextContent('policy.xml')
  }
}

resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [
  for (config, i) in openAIConfig: if (length(openAIConfig) > 0) {
    name: config.name
    parent: apimService
    properties: {
      description: 'backend description'
      url: '${cognitiveServices[i].properties.endpoint}/openai'
      protocol: 'http'
      circuitBreaker: {
        rules: [
          {
            failureCondition: {
              count: 3
              errorReasons: [
                'Server errors'
              ]
              interval: 'PT5M'
              statusCodeRanges: [
                {
                  min: 429
                  max: 429
                }
              ]
            }
            name: 'openAIBreakerRule'
            tripDuration: 'PT1M'
          }
        ]
      }
    }
  }
]

resource backendPoolOpenAI 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if (length(openAIConfig) > 1) {
  name: openAIBackendPoolName
  parent: apimService
  properties: {
    description: openAIBackendPoolDescription
    type: 'Pool'
    //    protocol: 'http'  // the protocol is not needed in the Pool type
    //    url: '${cognitiveServices[0].properties.endpoint}/openai'   // the url is not needed in the Pool type
    pool: {
      services: [
        for (config, i) in openAIConfig: {
          id: '/backends/${backendOpenAI[i].name}'
        }
      ]
    }
  }
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  name: openAISubscriptionName
  parent: apimService
  properties: {
    allowTracing: true
    displayName: openAISubscriptionDescription
    scope: '/apis'
    state: 'active'
  }
}

resource apiTestConnection 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: 'test-connection'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'Test connection to APIM from public and private network'
    displayName: 'Test Connection API'
    path: 'ip'
    protocols: ['http','https']
    type: 'http'
    serviceUrl: 'https://ifconfig.me/ip'
    subscriptionRequired: false
  }
}

// // APIM OpenAI API
// module openAIAPIModule '../../modules/apim/v1/openai-api.bicep' = {
//   name: 'openAIAPIModule'
//   params: {
//     policyXml: updatedPolicyXml
//     openAIConfig: openAIModule.outputs.extendedOpenAIConfig
//     openAIAPIVersion: openAIAPIVersion
//   }
// }

// Private Endpoint for APIM
resource privateEndpointApim 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'privateEndpoint-apim'
  location: resourceGroup().location
  properties: {
    customNetworkInterfaceName: 'nic-pe-apim'
    subnet: {
      id: virtualNetwork::subnetVm.id
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-apim'
        properties: {
          privateLinkServiceId: apimService.id
          groupIds: ['Gateway']
        }
      }
    ]
  }
}

resource privateDnsZoneApim 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azure-api.net'
  location: 'global'
}

resource privateDnsZoneLinkApim 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'link-apim'
  location: 'global'
  parent: privateDnsZoneApim
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource privateDnsZoneGroupApim 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: 'dnsZoneGroup-apim'
  parent: privateEndpointApim
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config-apim'
        properties: {
          privateDnsZoneId: privateDnsZoneApim.id
        }
      }
    ]
  }
}

// Azure Front Door
resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 60
    }
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: frontDoorOriginName
  parent: frontDoorOriginGroup
  properties: {
    hostName: replace(apimService.properties.gatewayUrl, 'https://', '')
    httpPort: 80
    httpsPort: 443
    originHostHeader: replace(apimService.properties.gatewayUrl, 'https://', '')
    priority: 1
    weight: 1000
    enabledState: 'Enabled'

    sharedPrivateLinkResource: {
      privateLink: {
        id: apimService.id
      }
      groupId: 'Gateway'
      privateLinkLocation: resourceGroup().location
      requestMessage: 'Please validate PE connection'
    }
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: ['Http', 'Https']
    patternsToMatch: ['/*']
    forwardingProtocol: 'MatchRequest' // 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    originPath: '/'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionHostName
  location: resourceGroup().location
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

// // Bastion Host
// module bastionModule '../../modules/bastion/v1/bastion.bicep' = {
//   name: 'bastionModule'
//   params: {
//     bastionHostName: 'bastion-host'
//     vnetId: virtualNetwork.id
//     location: resourceGroup().location
//   }
// }

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
            id: virtualNetwork::subnetVm.id
          }
        }
      }
    ]
  } 
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' =  {
  name: vmName
  location: resourceGroup().location
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
        name: 'osdisk-${vmName}'
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

// // Jumpbox VM
// module vmModule '../../modules/virtual-machine/vm.bicep' = {
//   name: 'vmModule'
//   params: {
//     vmName: 'vm-win11'
//     location: resourceGroup().location
//     vmSize: 'Standard_D2ads_v5'
//     subnetVmId: virtualNetwork::subnetVm.id
//     vmAdminUsername: 'azureuser'
//     vmAdminPassword: '@Aa123456789' // should be secured in real world
//   }
// }

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
output apimResourceGatewayURL string = apimService.properties.gatewayUrl
#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey
output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
