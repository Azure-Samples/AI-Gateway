// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apimSku string

@description('The relative path of the APIM API for OpenAI API')
param openAIAPIPath string = 'openai'

@description('Full URL for the OpenAI API spec')
param openAIAPISpecURL string = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json'

@description('The name of the APIM Subscription for OpenAI API')
param openAISubscriptionName string = 'openai-subscription'

@description('The name of the APIM API for OpenAI API')
param openAIAPIName string = 'openai'

@description('Public network access for APIM')
@allowed([
  'Enabled'
  'Disabled'
])
param apimPublicNetworkAccess string = 'Enabled'

@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorEndpointName string = 'afd-${uniqueString(resourceGroup().id)}'

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Premium_AzureFrontDoor'

@description('Name of the virtual machine')
param vmName string = 'vm-jumpbox'

@description('The admin username for the virtual machine')
param vmAdminUsername string = 'azureuser'

@description('The display name for the MCP Entra application')
param mcpEntraAppName string

@description('MCP App Client ID - if already created manually, provide it here to skip automatic creation')
param mcpClientId string = ''

@secure()
@description('The admin password for the virtual machine')
// Ignoring the password warning as this is strictly for demo purposes and should be secured in a real-world scenario.
#disable-next-line secure-parameter-default
param vmAdminPassword string = '@Aa123456789' // should be secured in real world

param modelsConfig array = []

param apicLocation string

// ------------------
//    VARIABLES
// ------------------

var suffix = uniqueString(subscription().id, resourceGroup().id)
var virtualNetworkName = 'vnet-spoke'
var subnetAiServicesName = 'snet-aiservices'
var subnetApimName = 'snet-apim'
var subnetVmName = 'snet-vm'
var peSubnetName = 'snet-pe'
var aiFoundryName = 'foundry${suffix}'
var aiFoundryProjectName = 'foundry-project-${suffix}'

// Account for all placeholders in the polixy.xml file.
var policyXml = loadTextContent('./policy.xml')
// ------------------
//    RESOURCES
// ------------------

// NSG for APIM Subnet
resource nsgApim 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-apim'
  location: resourceGroup().location
}

// NSG for VM Subnet
resource nsgVm 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-vm'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
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
          networkSecurityGroup: {
            id: nsgVm.id
          }
        }
      }
      {
        name: peSubnetName
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

  resource subnetVm 'subnets' existing = {
    name: subnetVmName
  }
}

resource subnetPe 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: virtualNetwork
  name: peSubnetName
  properties: {
    addressPrefix: '10.0.3.0/24'
  }
}


// Create Foundry Account
module foundryAccountModule './modules/foundry.bicep' = {
  name: 'foundryAccountDeployment'
  params: {
    location: resourceGroup().location
    aiFoundryName: aiFoundryName
    aiFoundryProjectName: aiFoundryProjectName
    modelsConfig: modelsConfig
    logAnalyticsName: 'log-analytics-${suffix}'
  }
}


// Create private endpoint if enabled
resource aiAccountPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${aiFoundryName}-private-endpoint'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: subnetPe.id                    // Deploy in customer hub subnet
    }
    privateLinkServiceConnections: [
      {
        name: '${aiFoundryName}-private-link-service-connection'
        properties: {
          privateLinkServiceId: foundryAccountModule.outputs.aiFoundryId
          groupIds: [
            'account'                     // Target AI Services account
          ]
        }
      }
    ]
  }
}

resource aiServicesPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.services.ai.azure.com'
  location: 'global'
}

resource openAiPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'
}

resource cognitiveServicesPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.cognitiveservices.azure.com'
  location: 'global'
}

// Link AI Services and Azure OpenAI and Cognitive Services DNS Zone to VNet
resource aiServicesLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: aiServicesPrivateDnsZone
  location: 'global'
  name: 'aiServices-link'
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id                        // Link to specified VNet
    }
    registrationEnabled: false           // Don't auto-register VNet resources
  }
}

resource aiOpenAILink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: openAiPrivateDnsZone
  location: 'global'
  name: 'aiServicesOpenAI-link'
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id                        // Link to specified VNet
    }
    registrationEnabled: false           // Don't auto-register VNet resources
  }
}

resource cognitiveServicesLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: cognitiveServicesPrivateDnsZone
  location: 'global'
  name: 'aiServicesCognitiveServices-link'
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id                      // Link to specified VNet
    }
    registrationEnabled: false           // Don't auto-register VNet resources
  }
}

// 3) DNS Zone Group for AI Services
resource aiServicesDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: aiAccountPrivateEndpoint
  name: '${aiFoundryName}-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${aiFoundryName}-dns-aiserv-config'
        properties: {
          privateDnsZoneId: aiServicesPrivateDnsZone.id
        }
      }
      {
        name: '${aiFoundryName}-dns-openai-config'
        properties: {
          privateDnsZoneId: openAiPrivateDnsZone.id
        }
      }
      {
        name: '${aiFoundryName}-dns-cogserv-config'
        properties: {
          privateDnsZoneId: cognitiveServicesPrivateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    aiServicesLink 
    cognitiveServicesLink
    aiOpenAILink
  ]
}



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
    virtualNetworkType: 'External' // "Internal" # Setting up 'Internal' Internal Virtual Network Type is not supported for Sku Type 'StandardV2'.
    publicNetworkAccess: apimPublicNetworkAccess // "Disabled" # Blocking all public network access by setting property `publicNetworkAccess` of API Management service is not enabled during service creation.
    virtualNetworkConfiguration: {
      subnetResourceId: virtualNetwork::subnetApim.id
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// apic
module apicModule './modules/apic.bicep' = {
  name: 'apicModule'
  params: {
    apicServiceName: 'apic-${suffix}'
    location: apicLocation
  }
}

// add mcp entra
module managedIdentityModule './modules/userAssignedIdentity.bicep' = {
  name: 'managedIdentityModule'
  params: {
    identityName: 'mi-mcp-${suffix}'
    location: resourceGroup().location
  }
}

module mcpEntraAppModule './modules/mcp-entra-app.bicep' = if (empty(mcpClientId)) {
  name: 'mcpEntraAppModule'
  params: {
    mcpAppUniqueName: mcpEntraAppName
    mcpAppDisplayName: mcpEntraAppName
    tenantId: subscription().tenantId
    userAssignedIdentityPrincipleId: managedIdentityModule.outputs.identityPrincipalId
  }
}

// PlaceOrder MCP 
module placeOrderAPIModule './src/place-order/api/api.bicep' = {
  name: 'placeOrderAPIModule'
  params: {
    apimServiceName: 'apim-${suffix}'
    apicServiceName: apicModule.outputs.name
    environmentName: apicModule.outputs.apiEnvironmentName
  }
  dependsOn: [
    apimService
    apicModule
  ]
}

module placeOrderMCPModule './src/place-order/mcp-server/mcp.bicep' = {
  name: 'placeOrderMCPModule'
  params: {
    apimServiceName: 'apim-${suffix}'
    apicServiceName: apicModule.outputs.name
    environmentName: apicModule.outputs.mcpEnvironmentName
    apiName: placeOrderAPIModule.outputs.name
    mcpAppId: mcpEntraAppModule.?outputs.mcpAppId 
    mcpAppTenantId: subscription().tenantId
  }
  dependsOn: [
    apicModule
    placeOrderAPIModule
    mcpEntraAppModule
  ]
}


resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: openAIAPIName
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'Azure OpenAI API inferencing API'
    displayName: 'OpenAI'
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
    value: loadTextContent('policy.xml')
  }
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  name: openAISubscriptionName
  parent: apimService
  properties: {
    allowTracing: true
    displayName: 'OpenAI Subscription'
    scope: '/apis'
    state: 'active'
  }
}

// Private Endpoint for APIM
resource privateEndpointApim 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'privateendpoint-apim'
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

  dependsOn: [
    frontDoorOrigin
  ]
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
  name: 'FrontDoor'
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
  name: 'OriginGroup'
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
  name: 'FrontDoorOrigin'
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
      groupId: 'Gateway'
      privateLinkLocation: resourceGroup().location
      requestMessage: 'Please validate PE connection'
      privateLink: {
        id: apimService.id
      }
    }
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: 'FrontDoorRoute'
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

// Frontdoor WAF Policy configuration
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: 'wafPolicyFrontdoor'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '1.1'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2021-06-01' = {
  parent: frontDoorProfile
  name: 'security-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

// // Approve private link connection for APIM
// resource approvePrivateLinkConnectionApim 'Microsoft.ApiManagement/service/privateEndpointConnections@2024-06-01-preview' = {
//   name: '4406a100-e485-4ed5-b3d6-911890f52e19'
//   parent: apimService
//   properties: {
//     privateLinkServiceConnectionState: {
//       status: 'Approved'
//       description: 'Auto-approved by Terraform'
//       actionsRequired: 'Nothing to change'
//     }
//   }
// }

// Azure Bastion Host
resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bastion-host'
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

// Public IP for VM
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-${vmName}'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

// Network Interface for VM
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
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: resourceGroup().location
  identity:{
    type: 'SystemAssigned'
  }
  properties: {
    priority: 'Spot'
    evictionPolicy: 'Deallocate'
    billingProfile: {
      maxPrice: -1
    }
    hardwareProfile: {
      vmSize: 'Standard_D2ads_v5'
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-25_04'
        sku: 'minimal'
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

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'customScript'
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: base64('''
        #!/bin/bash
        set -e
        
        # Update package lists
        apt-get update
        
        # Install Python and venv
        apt-get install -y python3 python3-pip python3-venv python3-full
        
        # Create a virtual environment for the azureuser
        mkdir -p /home/azureuser/scripts
        python3 -m venv /home/azureuser/venv
        
        # Install packages in the virtual environment
        /home/azureuser/venv/bin/pip install --upgrade pip
        /home/azureuser/venv/bin/pip install requests azure-identity azure-ai-projects azure-ai-agents==1.2.0b6 requests jsonref python-dotenv azure-keyvault-secrets

        # Set ownership
        chown -R azureuser:azureuser /home/azureuser/venv
        chown -R azureuser:azureuser /home/azureuser/scripts
        
        echo "Setup completed successfully"
      ''')
    }
  }
}

resource vmAiDeveloperRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vm.id, aiFoundryName, '')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d') // Azure AI User
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    vm
  ]
}


resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'app-insights'
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: foundryAccountModule.outputs.logAnalyticsWorkspaceId
    // CustomMetricsOptedInType: 'WithDimensions'
  }
}


resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: 'appinsights-logger'
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: 'APIM Logger for OpenAI API'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

var logSettings = {
  headers: [
    'Content-type'
    'User-agent'
    'x-ms-region'
    'x-ratelimit-remaining-tokens'
    'x-ratelimit-remaining-requests'
  ]
  body: { bytes: 8192 }
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: api
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: apimLogger.id
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

// Collect logs from Frontdoor
resource logAnalyticsWorkspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontDoorProfile
  name: 'diagnosticSettings'
  properties: {
    workspaceId: foundryAccountModule.outputs.logAnalyticsWorkspaceId
    logs: [
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
      }
      {
        category: 'FrontDoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontDoorHealthProbeLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Key Vault module
module keyVaultModule './modules/keyvault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyVaultName: 'kv-${suffix}'
    location: resourceGroup().location
    tenantId: subscription().tenantId
    vmPrincipalId: vm.identity.principalId
    privateEndpointSubnetId: subnetPe.id
    virtualNetworkId: virtualNetwork.id
    secrets: {
      'MCP-SERVER-URL': 'https://${frontDoorEndpoint.properties.hostName}/order-mcp/mcp'
      'MCP-SERVER-LABEL': 'order_mcp'
      'AZURE-AI-PROJECT-ENDPOINT': foundryAccountModule.outputs.aiFoundryProjectEndpoint
      'AZURE-AI-MODEL-DEPLOYMENT-NAME': modelsConfig[0].name
    }
  }
  dependsOn: [
    vm
    foundryAccountModule
    frontDoorEndpoint
  ]
}

// ------------------
//    MARK: OUTPUTS
// ------------------
output apimResourceId string = apimService.id
output apimResourceGatewayURL string = apimService.properties.gatewayUrl
#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey
output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
output ai_project_endpoint string = foundryAccountModule.outputs.aiFoundryProjectEndpoint
output ai_model_deployment_name string = modelsConfig[0].name
output keyVaultUrl string = keyVaultModule.outputs.keyVaultUrl
