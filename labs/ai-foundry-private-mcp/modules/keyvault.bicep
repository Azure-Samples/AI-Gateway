@description('Key Vault name')
param keyVaultName string

@description('Location for the Key Vault')
param location string

@description('Tenant ID for RBAC')
param tenantId string

@description('Principal ID to grant Key Vault Secrets User role')
param vmPrincipalId string

@description('Secrets to store in Key Vault as key-value pairs')
param secrets object

@description('Subnet ID for private endpoint')
param privateEndpointSubnetId string

@description('Virtual Network ID for DNS zone link')
param virtualNetworkId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    publicNetworkAccess: 'Disabled'  // Disable public access
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// Grant VM identity access to Key Vault
resource vmKvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vmPrincipalId, keyVault.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Create all secrets in a loop
resource kvSecrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [for secret in items(secrets): {
  parent: keyVault
  name: secret.key
  properties: {
    value: secret.value
  }
}]

// Private endpoint for Key Vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${keyVaultName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
}

// Private DNS Zone for Key Vault
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
}

// Link DNS Zone to VNet
resource keyVaultDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultPrivateDnsZone
  name: '${keyVaultName}-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
    registrationEnabled: false
  }
}

// DNS Zone Group
resource keyVaultDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: keyVaultPrivateEndpoint
  name: '${keyVaultName}-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vault-config'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

output keyVaultName string = keyVault.name
output keyVaultUrl string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
