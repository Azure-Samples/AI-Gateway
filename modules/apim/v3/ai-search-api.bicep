/**
 * @module ai-search-api
 * @description Creates a PassThrough API in APIM that proxies requests to Azure AI Search.
 * Uses managed identity authentication with the https://search.azure.com resource.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('The suffix to append to the API Management instance name.')
param resourceSuffix string = uniqueString(subscription().id, resourceGroup().id)

@description('The name of the API Management instance.')
param apiManagementName string = 'apim-${resourceSuffix}'

@description('Id of the APIM Logger')
param apimLoggerId string = ''

@description('The instrumentation key for Application Insights')
@secure()
param appInsightsInstrumentationKey string = ''

@description('The resource ID for Application Insights')
param appInsightsId string = ''

@description('The Azure AI Search service endpoint URL (e.g. https://<name>.search.windows.net)')
param searchServiceEndpoint string

@description('The Azure AI Search service name (used as the APIM backend name)')
param searchServiceName string

@description('The API path in APIM for the AI Search passthrough')
param searchAPIPath string = 'ai-search'

@description('The display name of the AI Search API in APIM')
param searchAPIDisplayName string = 'AI Search API'

// ------------------
//    VARIABLES
// ------------------

var logSettings = {
  headers: [ 'Content-type', 'User-agent' ]
  body: { bytes: 8192 }
}

var searchBackendName = searchServiceName

var policyXml = '''
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="{backend-id}" />
        <authentication-managed-identity resource="https://search.azure.com" output-token-variable-name="managed-id-access-token" />
        <set-header name="api-key" exists-action="delete" />
        <set-header name="Authorization" exists-action="override">
            <value>@("Bearer " + (string)context.Variables["managed-id-access-token"])</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'''

var updatedPolicyXml = replace(policyXml, '{backend-id}', searchBackendName)

// ------------------
//    RESOURCES
// ------------------

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apiManagementName
}

// Backend pointing to Azure AI Search with managed identity auth
resource searchBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: searchBackendName
  parent: apimService
  properties: {
    description: 'Azure AI Search backend'
    url: searchServiceEndpoint
    protocol: 'http'
    credentials: {
      #disable-next-line BCP037
      managedIdentity: {
        resource: 'https://search.azure.com'
      }
    }
  }
}

// PassThrough API with wildcard path — forwards all requests to AI Search
resource api 'Microsoft.ApiManagement/service/apis@2025-03-01-preview' = {
  name: 'ai-search-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'PassThrough API to Azure AI Search'
    displayName: searchAPIDisplayName
    format: 'openapi+json'
    path: searchAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
      #disable-next-line BCP037
      bearer: 'enabled'
    }
    subscriptionRequired: true
    type: 'http'
    value: string(loadJsonContent('./specs/PassThrough.json'))
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: updatedPolicyXml
  }
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = if(length(apimLoggerId) > 0) {
  parent: api
  name: 'azuremonitor'
  properties: {
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    loggerId: apimLoggerId
    sampling: {
      samplingType: 'fixed'
      percentage: json('100')
    }
    frontend: {
      request: {
        headers: []
        body: { bytes: 0 }
      }
      response: {
        headers: []
        body: { bytes: 0 }
      }
    }
    backend: {
      request: {
        headers: []
        body: { bytes: 0 }
      }
      response: {
        headers: []
        body: { bytes: 0 }
      }
    }
  }
}

resource apiDiagnosticsAppInsights 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if (!empty(appInsightsId) && !empty(appInsightsInstrumentationKey)) {
  name: 'applicationinsights'
  parent: api
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apiManagementName, 'appinsights-logger')
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

output apiId string = api.id
output searchBackendName string = searchBackend.name
output searchAPIPath string = searchAPIPath
