// ------------------
//    PARAMETERS
// ------------------

@description('The pricing tier of this API Management service')
@allowed([
  'Developer'
  'Basicv2'
  'Standardv2'
])
param apimSku string = 'Basicv2'

@description('Configuration array for APIM subscriptions')
param apimSubscriptionsConfig array = []

@description('The path to the inference API in the APIM service')
param inferenceAPIPath string = 'openai'

@description('The location for the Container Apps Environment. Must support GPU workload profiles.')
param acaLocation string = 'swedencentral'

@description('The SGLang Docker image to deploy')
param sglangImage string = 'lmsysorg/sglang:latest'

@description('The model path for SGLang to serve (HuggingFace model ID)')
param sglangModelPath string = 'meta-llama/Llama-3.1-8B-Instruct'

@description('The HuggingFace token for accessing gated models')
@secure()
param huggingFaceToken string = ''

@description('The GPU workload profile name')
// NC8as-T4 or NC24-A100
param gpuWorkloadProfileName string = 'NC24-A100'

@description('The GPU workload profile type')
@allowed([
  'Consumption-GPU-NC24-A100'
  'Consumption-GPU-NC8as-T4'
])
param gpuWorkloadProfileType string = 'Consumption-GPU-NC24-A100'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'
var policyXml = loadTextContent('policy.xml')

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
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 4. Container Apps Environment with GPU workload profile
resource acaEnvironment 'Microsoft.App/managedEnvironments@2024-08-02-preview' = {
  name: 'aca-env-${resourceSuffix}'
  location: acaLocation
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: lawModule.outputs.customerId
        sharedKey: lawModule.outputs.primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
      {
        name: gpuWorkloadProfileName
        workloadProfileType: gpuWorkloadProfileType
      }
    ]
  }
}

// 5. Container App running SGLang
resource sglangApp 'Microsoft.App/containerApps@2024-08-02-preview' = {
  name: 'sglang-${resourceSuffix}'
  location: acaLocation
  properties: {
    environmentId: acaEnvironment.id
    workloadProfileName: gpuWorkloadProfileName
    configuration: {
      ingress: {
        external: true
        targetPort: 30000
        transport: 'http'
        allowInsecure: false
      }
      secrets: !empty(huggingFaceToken) ? [
        {
          name: 'hf-token'
          value: huggingFaceToken
        }
      ] : []
    }
    template: {
      containers: [
        {
          name: 'sglang'
          image: sglangImage
          resources: {
            cpu: 24
            memory: '220Gi'
          }
          env: concat(
            [
              {
                name: 'SGLANG_MODEL_PATH'
                value: sglangModelPath
              }
            ],
            !empty(huggingFaceToken) ? [
              {
                name: 'HF_TOKEN'
                secretRef: 'hf-token'
              }
            ] : []
          )
          command: [
            'python3'
            '-m'
            'sglang.launch_server'
            '--model-path'
            sglangModelPath
            '--host'
            '0.0.0.0'
            '--port'
            '30000'
            '--mem-fraction-static'
            '0.9'
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}

// 6. APIM Backend pointing to the Container App
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    apimModule
  ]
}

resource sglangBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'sglang-backend'
  parent: apim
  properties: {
    description: 'SGLang GPU inference backend on Azure Container Apps'
    url: 'https://${sglangApp.properties.configuration.ingress.fqdn}/v1'
    protocol: 'http'
  }
}

// 7. APIM API (PassThrough - OpenAI compatible)
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'inference-api'
  parent: apim
  properties: {
    apiType: 'http'
    description: 'SGLang OpenAI-compatible inference API served from Azure Container Apps with GPU'
    displayName: 'Inference API'
    format: 'openapi+json'
    path: inferenceAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: string(loadJsonContent('../../modules/apim/v3/specs/PassThrough.json'))
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: replace(policyXml, '{backend-id}', sglangBackend.name)
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' existing = {
  parent: apim
  name: 'azuremonitor'
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: api
  name: 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: apimLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: json('100')
    }
  }
  dependsOn: [
    apimModule
  ]
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output sglangFqdn string = sglangApp.properties.configuration.ingress.fqdn
