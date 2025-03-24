param apimServiceName string
param APIServiceURL string
param APIPath string = 'servicenow'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'servicenow-mcp'
  properties: {
    displayName: 'ServiceNow MCP'
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

resource APIPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    value: loadTextContent('policy.xml')
    format: 'rawxml'
  }
}

resource authorizationProvider 'Microsoft.ApiManagement/service/authorizationProviders@2024-06-01-preview' = {
  parent: apim
  name: 'servicenow'
  properties: {
    displayName: 'servicenow'
    identityProvider: 'servicenow'
    oauth2: {
      redirectUrl: 'https://authorization-manager.consent.azure-apim.net/redirect/apim/${apim.name}'
      grantTypes: {
        authorizationCode: {
          clientId: '54c92d51cee94dd59a5ff2761f1908b0'
          clientSecret: 'redacted'
          scopes: ''
          instanceName: 'dev306445'
        }
      }
    }
  }
}

resource ListIncidentsOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'ListIncidents'
}

resource ListIncidentsOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: ListIncidentsOperation
  name: 'policy'
  properties: {
    value: loadTextContent('operation-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}

resource CreateIncidentOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'CreateIncident'
}

resource CreateIncidentOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: CreateIncidentOperation
  name: 'policy'
  properties: {
    value: loadTextContent('operation-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}

resource GetIncidentOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: api
  name: 'GetIncident'
}

resource GetIncidentOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: GetIncidentOperation
  name: 'policy'
  properties: {
    value: loadTextContent('operation-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apim
  ]
}
