@description('Azure region for the deployment')
param location string

@description('The name of the virtual network')
param vnetName string

@description('Indicates if an existing VNet should be used')
param useExistingVnet bool = false

@description('Subscription ID of the existing VNet (if different from current subscription)')
param existingVnetSubscriptionId string = subscription().subscriptionId

@description('Resource Group name of the existing VNet (if different from current resource group)')
param existingVnetResourceGroupName string = resourceGroup().name

@description('The name of Agents Subnet')
param agentSubnetName string = 'agent-subnet'

@description('The name of Private Endpoint subnet')
param peSubnetName string = 'pe-subnet'

@description('The name of MCP subnet for user-deployed Container Apps')
param mcpSubnetName string = 'mcp-subnet'

@description('Address space for the VNet (only used for new VNet)')
param vnetAddressPrefix string = ''

@description('Address prefix for the agent subnet')
param agentSubnetPrefix string = ''

@description('Address prefix for the private endpoint subnet')
param peSubnetPrefix string = ''

@description('Address prefix for the MCP subnet')
param mcpSubnetPrefix string = ''

// Create new VNet if needed
module newVNet 'vnet.bicep' = if (!useExistingVnet) {
  name: 'vnet-deployment'
  params: {
    location: location
    vnetName: vnetName
    agentSubnetName: agentSubnetName
    peSubnetName: peSubnetName
    mcpSubnetName: mcpSubnetName
    vnetAddressPrefix: vnetAddressPrefix
    agentSubnetPrefix: agentSubnetPrefix
    peSubnetPrefix: peSubnetPrefix
    mcpSubnetPrefix: mcpSubnetPrefix
  }
}

// Use existing VNet if requested
module existingVNet 'existing-vnet.bicep' = if (useExistingVnet) {
  name: 'existing-vnet-deployment'
  params: {
    vnetName: vnetName
    vnetResourceGroupName: existingVnetResourceGroupName
    vnetSubscriptionId: existingVnetSubscriptionId
    agentSubnetName: agentSubnetName
    peSubnetName: peSubnetName
    mcpSubnetName: mcpSubnetName
    agentSubnetPrefix: agentSubnetPrefix
    peSubnetPrefix: peSubnetPrefix
    mcpSubnetPrefix: mcpSubnetPrefix
  }
}

// Provide unified outputs regardless of which module was used
output virtualNetworkName string = useExistingVnet
  ? existingVNet.outputs.virtualNetworkName
  : newVNet.outputs.virtualNetworkName
output virtualNetworkId string = useExistingVnet
  ? existingVNet.outputs.virtualNetworkId
  : newVNet.outputs.virtualNetworkId
output virtualNetworkSubscriptionId string = useExistingVnet
  ? existingVNet.outputs.virtualNetworkSubscriptionId
  : newVNet.outputs.virtualNetworkSubscriptionId
output virtualNetworkResourceGroup string = useExistingVnet
  ? existingVNet.outputs.virtualNetworkResourceGroup
  : newVNet.outputs.virtualNetworkResourceGroup
output agentSubnetName string = agentSubnetName
output peSubnetName string = peSubnetName
output mcpSubnetName string = mcpSubnetName
output agentSubnetId string = useExistingVnet ? existingVNet.outputs.agentSubnetId : newVNet.outputs.agentSubnetId
output peSubnetId string = useExistingVnet ? existingVNet.outputs.peSubnetId : newVNet.outputs.peSubnetId
output mcpSubnetId string = useExistingVnet ? existingVNet.outputs.mcpSubnetId : newVNet.outputs.mcpSubnetId
