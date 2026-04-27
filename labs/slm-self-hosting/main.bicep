// ------------------
//    PARAMETERS
// ------------------

// Typically, parameters would be decorated with appropriate metadata and attributes, but as they are very repetetive in these labs we omit them for brevity.

param apimSku string
param openAIAPIVersion string = '2024-02-01'
param selfHostedGatewayName string = 'self-hosted-gateway'
// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)
var apiManagementName = 'apim-${resourceSuffix}'
var apimSubscriptionName = 'apim-subscription'
var apimSubscriptionDescription = 'APIM Subscription'
var openAIAPIName = 'openai'

// Account for all placeholders in the polixy.xml file.
var policyXml = loadTextContent('policy.xml')

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

var lawId = lawModule.outputs.id

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawId
    customMetricsOptedInType: 'WithDimensions'
  }
}

var appInsightsId = appInsightsModule.outputs.id
var appInsightsInstrumentationKey = appInsightsModule.outputs.instrumentationKey

// 3. API Management
module apimModule '../../modules/apim/v1/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
  }
}

// We presume the APIM resource has been created as part of this bicep flow.
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
  dependsOn: [
    apimModule
  ]
}


resource apimDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apim
  name: 'apimDiagnosticSettings'
  properties: {
    workspaceId: lawId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apim
  name: 'azuremonitor'
  properties: {
    loggerType: 'azureMonitor'
    isBuffered: false // Set to false to ensure logs are sent immediately
  }
}

// Ignore the subscription that gets created in the APIM module and create three new ones for this lab.
resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: apimSubscriptionName
  parent: apim
  properties: {
    allowTracing: true
    displayName: apimSubscriptionDescription
    scope: '/apis'
    state: 'active'
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
    name: 'ai-model-inference'
    parent: apim
    properties: {
      apiType: 'http'
      description: 'AI Model Inference'
      displayName: 'AI Model Inference'
      format: 'openapi-link'
      path: 'inference'
      serviceUrl: 'http://host.docker.internal:5273/v1'
      protocols: [
        'https', 'http'
      ]
      subscriptionKeyParameterNames: {
        header: 'api-key'
        query: 'api-key'
      }
      subscriptionRequired: true
      type: 'http'
      value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/refs/heads/main/specification/ai/data-plane/ModelInference/openapi/2024-05-01-preview/openapi.yaml'
    }
  }

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: loadTextContent('policy.xml')
  }
}


resource selfHostedGateway 'Microsoft.ApiManagement/service/gateways@2021-08-01' = {
  name: selfHostedGatewayName
  parent: apim
  properties:{
    description: 'Self-hosted gateway'
    locationData: {
      name: 'Lisbon'
      countryOrRegion: 'Portugal'
    }
  }
}

resource gatewayAPIResource 'Microsoft.ApiManagement/service/gateways/apis@2021-08-01' = {
  name: '${apim.name}/${selfHostedGatewayName}/${api.name}'
  properties: {}
}



// ------------------
//    OUTPUTS
// ------------------

output applicationInsightsAppId string = appInsightsModule.outputs.appId
output applicationInsightsName string = appInsightsModule.outputs.applicationInsightsName
output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimResourceId string = apim.id
output apimResourceName string = apim.name

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey
