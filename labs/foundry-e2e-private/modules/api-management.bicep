// Conditionally creates or references an existing Azure API Management service

@description('Azure region of the deployment')
param location string

@description('The name of the API Management service to create')
param apiManagementName string

@description('The SKU of the API Management service. StandardV2 supports private endpoints.')
@allowed([
  'StandardV2'
  'PremiumV2'
])
param apiManagementSku string = 'StandardV2'

@description('The capacity (scale units) of the API Management service')
param apiManagementCapacity int = 1

@description('Publisher email for the API Management service')
param publisherEmail string

@description('Publisher name for the API Management service')
param publisherName string

@description('Subnet resource ID for outbound VNet integration. Required for private backend connectivity.')
param apimSubnetId string = ''

@description('The API Management Service full ARM Resource ID. If provided, the existing resource will be used.')
param apiManagementResourceId string = ''

@description('Whether the existing API Management resource was validated successfully')
param apiManagementExists bool = false

var apimParts = split(apiManagementResourceId, '/')

resource existingApiManagement 'Microsoft.ApiManagement/service@2024-05-01' existing = if (apiManagementExists) {
  name: apimParts[8]
  scope: resourceGroup(apimParts[2], apimParts[4])
}

resource apiManagement 'Microsoft.ApiManagement/service@2024-05-01' = if (!apiManagementExists) {
  name: apiManagementName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: apiManagementSku
    capacity: apiManagementCapacity
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    // publicNetworkAccess must be 'Enabled' during creation.
    // Disable it after configuring the private endpoint.
    publicNetworkAccess: 'Enabled'
    // Outbound VNet integration for private backend connectivity
    virtualNetworkType: !empty(apimSubnetId) ? 'External' : 'None'
    virtualNetworkConfiguration: !empty(apimSubnetId) ? {
      subnetResourceId: apimSubnetId
    } : null
  }
}

output apiManagementName string = apiManagementExists ? existingApiManagement.name : apiManagement.name
output apiManagementId string = apiManagementExists ? existingApiManagement.id : apiManagement.id
output apiManagementResourceGroupName string = apiManagementExists ? apimParts[4] : resourceGroup().name
output apiManagementSubscriptionId string = apiManagementExists ? apimParts[2] : subscription().subscriptionId
