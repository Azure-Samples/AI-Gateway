param apimServiceName string
param graphqlUpstreamUrl string
param graphqlAPIPath string = 'countries-graphql'

resource apimService 'Microsoft.ApiManagement/service@2025-09-01-preview' existing = {
  name: apimServiceName
}

resource graphqlAPI 'Microsoft.ApiManagement/service/apis@2025-09-01-preview' = {
  parent: apimService
  name: 'countries-graphql-api'
  properties: {
    apiType: 'graphql'
    type: 'graphql'
    displayName: 'Countries GraphQL API'
    description: 'Pass-through GraphQL API for country data.'
    path: graphqlAPIPath
    protocols: [
      'https'
    ]
    subscriptionRequired: false
    format: 'graphql-link'
    value: graphqlUpstreamUrl
  }
}

resource graphqlPolicy 'Microsoft.ApiManagement/service/apis/policies@2025-09-01-preview' = {
  parent: graphqlAPI
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('policy.xml')
  }
}

output name string = graphqlAPI.name
output endpoint string = '${apimService.properties.gatewayUrl}/${graphqlAPIPath}'
