
param apimServiceName string
param APIServiceURL string
param APIPath string = 'github'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
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
      header: 'api-key'
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

resource userOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'user'
}

resource userOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: userOperation
  name: 'policy'
  properties: {
    value: loadTextContent('operation-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}

resource issuesOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'issues'
}

resource issuesOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: issuesOperation
  name: 'policy'
  properties: {
    value: loadTextContent('operation-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}
