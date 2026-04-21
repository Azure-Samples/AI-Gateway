// ------------------
//    PARAMETERS
// ------------------

@description('The pricing tier of the API Management service')
param apimSku string = 'Basicv2'

@description('Configuration array for APIM subscriptions')
param apimSubscriptionsConfig array = []

@description('The Ollama model to pull on startup')
param ollamaModel string = 'mxbai-embed-large'

@description('CPU cores for the ACI container')
param aciCpu int = 2

@description('Memory in GB for the ACI container')
param aciMemoryInGB int = 8

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'
var containerGroupName = 'aci-ollama-${resourceSuffix}'
var location = resourceGroup().location

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawModule.outputs.id
    customMetricsOptedInType: 'WithDimensions'
  }
}

// 3. API Management
module apimModule '../../modules/apim/v3/apim.bicep' = {
  name: 'apimModule'
  params: {
    apiManagementName: apiManagementName
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 4. Azure Container Instance running Ollama (public image from Docker Hub)
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: 11434
          protocol: 'TCP'
        }
      ]
    }
    containers: [
      {
        name: 'ollama'
        properties: {
          image: 'ollama/ollama:latest'
          resources: {
            requests: {
              cpu: aciCpu
              memoryInGB: aciMemoryInGB
            }
          }
          ports: [
            {
              port: 11434
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'OLLAMA_HOST'
              value: '0.0.0.0:11434'
            }
          ]
          command: [
            '/bin/sh'
            '-c'
            'ollama serve & sleep 15 && ollama pull ${ollamaModel} && wait'
          ]
        }
      }
    ]
  }
}

// 5. APIM Backend pointing to ACI public IP
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    apimModule
    containerGroup
  ]

}

resource ollamaBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apimService
  name: 'ollama-backend'
  properties: {
    protocol: 'http'
    url: 'http://${containerGroup.properties.ipAddress.ip}:11434/v1'
    description: 'Self-hosted Ollama on ACI'
  }
}

// 6. APIM API for Ollama (OpenAI-compatible)
resource ollamaApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apimService
  name: 'ollama-inference'
  properties: {
    apiType: 'http'
    description: 'Self-hosted Ollama Embeddings API'
    displayName: 'Ollama Inference'
    path: 'ollama'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
  }
}

// 7. Catch-all POST operation so any sub-path is forwarded
resource ollamaApiPostOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: ollamaApi
  name: 'post-all'
  properties: {
    displayName: 'POST Catch All'
    method: 'POST'
    urlTemplate: '/{*path}'
    templateParameters: [
      {
        name: 'path'
        required: true
        type: 'string'
      }
    ]
  }
}

// 7b. Catch-all GET operation (for model listing, health checks)
resource ollamaApiGetOp 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: ollamaApi
  name: 'get-all'
  properties: {
    displayName: 'GET Catch All'
    method: 'GET'
    urlTemplate: '/{*path}'
    templateParameters: [
      {
        name: 'path'
        required: true
        type: 'string'
      }
    ]
  }
}

// 8. API-level policy
resource ollamaApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: ollamaApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('policy.xml')
  }
  dependsOn: [
    ollamaBackend
  ]
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output aciPublicIP string = containerGroup.properties.ipAddress.ip
