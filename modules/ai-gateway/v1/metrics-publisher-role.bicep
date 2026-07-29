targetScope = 'resourceGroup'

param appInsightsId string
param gatewayPrincipalId string
param gatewayResourceId string

var monitoringMetricsPublisherRoleDefinitionId = '3913510d-42f4-4e42-8a64-420c390055eb'

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: last(split(appInsightsId, '/'))
}

resource monitoringMetricsPublisherRoleAssignmentToAppInsights 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appInsights
  name: guid(appInsights.id, gatewayResourceId, gatewayPrincipalId, monitoringMetricsPublisherRoleDefinitionId)
  properties: {
    principalId: gatewayPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherRoleDefinitionId)
  }
}

