param apimServiceName string
param MCPServiceURL string
param APIPath string = 'spotify'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}


resource mcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'spotify-mcp'
  properties: {
    displayName: 'Spotify MCP'
    apiRevision: '1'
    subscriptionRequired: false
    serviceUrl: MCPServiceURL
    path: '${APIPath}/mcp'
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
    value: loadTextContent('mcp-openapi.json')
  }
}


resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'spotify-api'
  properties: {
    displayName: 'Spotify API'
    apiRevision: '1'
    subscriptionRequired: false
    serviceUrl: 'https://api.spotify.com/v1'
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
    format: 'openapi'
    value: string(loadJsonContent('openapi.json'))
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
  name: 'spotify'
  properties: {
    displayName: 'spotify'
    identityProvider: 'oauth2pkce'
    oauth2: {
      redirectUrl: 'https://authorization-manager.consent.azure-apim.net/redirect/apim/${apim.name}'
      grantTypes: {
        authorizationCode: {
          clientId: 'changeme'
          clientSecret: 'changeme'
          scopes: 'user-read-private,user-read-email,user-modify-playback-state,user-read-currently-playing,user-read-playback-state,app-remote-control,streaming,playlist-read-private,playlist-read-collaborative,playlist-modify-private,playlist-modify-public,user-read-playback-position,user-top-read,user-read-recently-played,user-library-modify,user-library-read'
          authorizationUrl: 'https://accounts.spotify.com/authorize'
          refreshUrl: 'https://accounts.spotify.com/api/token'
          tokenUrl: 'https://accounts.spotify.com/api/token'
        }
      }
    }
  }
}
