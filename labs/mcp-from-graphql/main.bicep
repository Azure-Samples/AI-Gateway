param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string = 'Basicv2'
param apimSubscriptionsConfig array = []
param inferenceAPIPath string = 'inference'
param foundryProjectName string = 'mcp-from-graphql'
param graphqlUpstreamUrl string = 'https://countries.trevorblades.com/graphql'
param graphqlAPIPath string = 'countries-graphql'
param mcpAPIPath string = 'countries-mcp'
param apicServiceNamePrefix string = 'apic'

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawModule.outputs.id
    customMetricsOptedInType: 'WithDimensions'
  }
}

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

module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
  name: 'foundryModule'
  params: {
    aiServicesConfig: aiServicesConfig
    modelsConfig: modelsConfig
    lawId: lawModule.outputs.id
    apimPrincipalId: apimModule.outputs.principalId
    foundryProjectName: foundryProjectName
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
    appInsightsConnectionString: appInsightsModule.outputs.connectionString
  }
}

module inferenceAPIModule '../../modules/apim/v3/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('inference-policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: 'AzureOpenAIV1'
    inferenceAPIPath: inferenceAPIPath
  }
}

module graphqlAPIModule 'src/graphql-api/api.bicep' = {
  name: 'graphqlAPIModule'
  params: {
    apimServiceName: apimModule.outputs.name
    graphqlUpstreamUrl: graphqlUpstreamUrl
    graphqlAPIPath: graphqlAPIPath
  }
}

module containerPlatformModule 'src/container-platform.bicep' = {
  name: 'containerPlatformModule'
  params: {
    resourceSuffix: resourceSuffix
    lawCustomerId: lawModule.outputs.customerId
    lawSharedKey: lawModule.outputs.primarySharedKey
    graphqlUrl: graphqlAPIModule.outputs.endpoint
  }
}

module mcpAPIModule 'src/mcp-api/api.bicep' = {
  name: 'mcpAPIModule'
  params: {
    apimServiceName: apimModule.outputs.name
    apimLoggerId: apimModule.outputs.loggerId
    backendName: 'countries-mcp-backend'
    backendDescription: 'Countries GraphQL MCP backend hosted on Azure Container Apps'
    backendUrl: containerPlatformModule.outputs.containerAppUrl
    mcpAPIPath: mcpAPIPath
  }
}

module apiCenterModule 'src/apic/catalog.bicep' = {
  name: 'apiCenterModule'
  params: {
    apicServiceName: '${apicServiceNamePrefix}-${resourceSuffix}'
    apimServiceName: apimModule.outputs.name
    apiSourceName: 'apim-${resourceSuffix}-source'
  }
  dependsOn: [
    graphqlAPIModule
    mcpAPIModule
  ]
}

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions
output inferenceAPIPath string = inferenceAPIPath
output graphqlEndpoint string = graphqlAPIModule.outputs.endpoint
output mcpEndpoint string = mcpAPIModule.outputs.endpoint
output apicServiceName string = apiCenterModule.outputs.name
output apicApiSourceName string = apiCenterModule.outputs.apiSourceName
output containerRegistryName string = containerPlatformModule.outputs.containerRegistryName
output containerAppName string = containerPlatformModule.outputs.containerAppName
output containerAppUrl string = containerPlatformModule.outputs.containerAppUrl
