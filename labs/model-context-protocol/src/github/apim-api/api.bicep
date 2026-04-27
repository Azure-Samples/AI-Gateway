
param apimServiceName string
param APIPath string = 'github'
param APIServiceURL string = 'https://api.github.com'
param authorizationProviderName string = 'github'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'github-api'
  properties: {
    displayName: 'GitHub API'
    subscriptionRequired: false
    serviceUrl: APIServiceURL
    path: '${APIPath}/api'
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

resource apiInsights 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: api
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apimServiceName, 'appinsights-logger')
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
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

/*
resource authorizationProvider 'Microsoft.ApiManagement/service/authorizationProviders@2024-06-01-preview' = {
  parent: apim
  name: authorizationProviderName
  properties: {
    displayName: authorizationProviderName
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
*/

