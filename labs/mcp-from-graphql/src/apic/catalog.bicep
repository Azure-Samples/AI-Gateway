param apicServiceName string
param apimServiceName string
param apiSourceName string
param location string = resourceGroup().location

var apiManagementServiceReaderRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '71522526-b88f-4d52-b57f-d31fc3546d0d'
)

resource apiCenterService 'Microsoft.ApiCenter/services@2024-06-01-preview' = {
  name: apicServiceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  #disable-next-line BCP187 // The API Center preview type omits the valid service-level SKU property.
  sku: {
    name: 'Free'
  }
}

resource apiCenterWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-06-01-preview' = {
  parent: apiCenterService
  name: 'default'
  properties: {
    title: 'Default workspace'
    description: 'API inventory for the GraphQL to MCP lab.'
  }
}

resource apiManagementEnvironment 'Microsoft.ApiCenter/services/workspaces/environments@2024-06-01-preview' = {
  parent: apiCenterWorkspace
  name: 'production-apim'
  properties: {
    title: 'Production API Management'
    description: 'APIM gateway hosting the GraphQL API and MCP server.'
    kind: 'production'
    server: {
      managementPortalUri: [
        'https://portal.azure.com/'
      ]
      type: 'Azure API Management'
    }
  }
}

resource apiManagementService 'Microsoft.ApiManagement/service@2025-09-01-preview' existing = {
  name: apimServiceName
}

resource apiCenterApiManagementReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(apiManagementService.id, apiCenterService.id, apiManagementServiceReaderRoleDefinitionId)
  scope: apiManagementService
  properties: {
    principalId: apiCenterService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: apiManagementServiceReaderRoleDefinitionId
  }
}

resource apiManagementSource 'Microsoft.ApiCenter/services/workspaces/apiSources@2024-06-01-preview' = {
  parent: apiCenterWorkspace
  name: apiSourceName
  properties: {
    azureApiManagementSource: {
      resourceId: apiManagementService.id
    }
    importSpecification: 'always'
    targetLifecycleStage: 'production'
    targetEnvironmentId: '/workspaces/${apiCenterWorkspace.name}/environments/${apiManagementEnvironment.name}'
  }
  dependsOn: [
    apiCenterApiManagementReaderRoleAssignment
  ]
}

output id string = apiCenterService.id
output name string = apiCenterService.name
output principalId string = apiCenterService.identity.principalId
output apiSourceName string = apiManagementSource.name
