param apimServiceName string
param agentName string
param APIServiceURL string
param APIPath string = 'weather'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-10-01-preview' = {
  parent: apim
  name: agentName
  properties: {
    displayName: '${agentName} Server'
    type: 'a2a'
    agent:{
      id: agentName
    }
    isAgent: true
    a2aProperties: {
      agentCardPath: '/.well-known/agent.json'
      agentCardBackendUrl: '${APIServiceURL}/.well-known/agent.json'
    }
    jsonRpcProperties: {
      backendUrl: APIServiceURL
      path: '/'
    }
    subscriptionRequired: true
    path: APIPath
    protocols: [
      'https'
      'http'
    ]
    authenticationSettings: {
      oAuth2AuthenticationSettings: []
      openidAuthenticationSettings: []
    }
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    isCurrent: true
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



