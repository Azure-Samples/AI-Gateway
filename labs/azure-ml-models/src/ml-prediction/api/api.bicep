param apimServiceName string
param amlEndpointUrl string
param apiPath string = 'ml-prediction'
param apiName string = 'ml-prediction-api'
param apiDisplayName string = 'ML Prediction API'
param apiDescription string = 'API for invoking an Azure ML online endpoint that serves a vaccine delivery forecasting model'

// ------------------
//    RESOURCES
// ------------------

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource mlBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: '${apiName}-backend'
  properties: {
    protocol: 'http'
    url: amlEndpointUrl
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    type: 'Single'
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: apiName
  properties: {
    apiType: 'http'
    displayName: apiDisplayName
    description: apiDescription
    apiRevision: '1'
    subscriptionRequired: false
    path: apiPath
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
    value: replace(loadTextContent('policy.xml'), '{backend-id}', mlBackend.name)
    format: 'rawxml'
  }
}

// ------------------
//    OUTPUTS
// ------------------

output name string = api.name
output endpoint string = '${apim.properties.gatewayUrl}/${apiPath}'
output operationName string = 'predict-forecast'
