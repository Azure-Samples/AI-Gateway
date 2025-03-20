
param APIServiceURL string

param APIPath string = 'github'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'github-mcp'
  properties: {
    displayName: 'GitHub MCP'
    apiRevision: '1'
    subscriptionRequired: false
    serviceUrl: APIServiceURL
    path: APIPath
    protocols: [
      'https'
    ]
    authenticationSettings: {
      oAuth2AuthenticationSettings: []
      openidAuthenticationSettings: []
    }
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    isCurrent: true
    format: 'openapi+json'
    value: loadTextContent('openapi.json')
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    value: loadTextContent('policy.xml')
    format: 'rawxml'
  }
}



resource authorizationProvider 'Microsoft.ApiManagement/service/authorizationProviders@2024-06-01-preview' = {
  parent: apim
  name: 'github'
  properties: {
    displayName: 'github'
    identityProvider: 'github'
    oauth2: {
      redirectUrl: 'https://authorization-manager.consent.azure-apim.net/redirect/apim/${apim.name}'
      grantTypes: {
        authorizationCode: {
          clientId: 'changeme'
          scopes: 'user repo'
        }
      }
    }
  }
}

resource armAPIVersionNV 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'ARMAPIVersion'
  properties: {
    displayName: 'ARMAPIVersion'
    value: '2024-05-01'
  }
}

resource resourceGroupNV 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'ResourceGroupId'
  properties: {
    displayName: 'ResourceGroupId'
    value: resourceGroup().name
  }
}

resource serviceIdNV 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'ServiceId'
  properties: {
    displayName: 'ServiceId'
    value: apim.name
  }
}

resource subscriptionIdNV 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'SubscriptionId'
  properties: {
    displayName: 'SubscriptionId'
    value: subscription().subscriptionId
  }
}

resource tenantIdNV 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'TenantId'
  properties: {
    displayName: 'TenantId'
    value: apim.identity.tenantId
  }
}

resource managedIdentityObjectIddNV 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  parent: apim
  name: 'ManagedIdentityObjectId'
  properties: {
    displayName: 'ManagedIdentityObjectId'
    value: apim.identity.principalId
  }
}


resource service_name_github_mcp_authorize 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'authorize'
}

resource service_name_github_mcp_authorize_policy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: service_name_github_mcp_authorize
  name: 'policy'
  properties: {
    value: loadTextContent('authorize-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}

resource service_name_github_mcp_messages 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'messages'
}

resource service_name_github_mcp_messages_policy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: service_name_github_mcp_messages
  name: 'policy'
  properties: {
    value: loadTextContent('messages-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}

resource service_name_github_mcp_sse 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'sse'
}

resource service_name_github_mcp_sse_policy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: service_name_github_mcp_sse
  name: 'policy'
  properties: {
    value: loadTextContent('sse-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}

resource service_name_github_mcp_token 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'token'
}

resource service_name_github_mcp_token_policy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: service_name_github_mcp_token
  name: 'policy'
  properties: {
    value: loadTextContent('token-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}

resource service_name_github_mcp_user 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'user'
}

resource service_name_github_mcp_user_policy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: service_name_github_mcp_user
  name: 'policy'
  properties: {
    value: loadTextContent('authenticated-user-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}


var apimContributorRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '312a565d-c81f-4fd8-895a-4e21e48d571c')
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  {
    scope: apim
    name: guid(subscription().id, resourceGroup().id, apimContributorRoleDefinitionID)
    properties: {
        roleDefinitionId: apimContributorRoleDefinitionID
        principalId: apim.identity.principalId
        principalType: 'ServicePrincipal'
    }
}
