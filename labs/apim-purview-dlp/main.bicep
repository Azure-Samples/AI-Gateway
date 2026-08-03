// -----------------------------------------------------------------------------
// labs/apim-purview-dlp/main.bicep
//
// Resource-group-scoped deployment for the "Microsoft Purview DLP at the AI
// Gateway" lab. Provisions:
//
//   * Log Analytics workspace (via ../../modules/operational-insights/v1)
//   * Application Insights   (via ../../modules/monitor/v1)
//   * API Management         (via ../../modules/apim/v2, StandardV2)
//   * AIGatewayContent_CL custom table + DCE + DCR (for prompt/response audit)
//   * APIM diagnostic setting → GatewayLogs to Log Analytics (Resource-specific)
//   * APIM policy fragments  : purview-processcontent, emit-content-log
//   * APIM named values      : gateway service principal (client id/secret),
//                              Foundry endpoint + agent name, Bedrock AWS keys,
//                              Purview endpoint, Logs Ingestion URL
//   * APIM APIs              : foundry-hrpolicy, bedrock-expense (both apply
//                              the shared Purview fragment)
//   * Role assignments       : APIM MI → Monitoring Metrics Publisher on DCR;
//                              optional single principal → Log Analytics Data
//                              Reader (granular RBAC on AIGatewayContent_CL)
//
// Cost disclaimer: SKU choices below (APIM StandardV2, Log Analytics
// PerGB2018, App Insights) have Azure list prices that vary by region, tier,
// currency, and negotiated agreement. All cost figures in this lab and its
// KQL are illustrative only — confirm authoritative pricing with your
// Microsoft account team before quoting anything against a real workload.
// -----------------------------------------------------------------------------

// ------------------
//    PARAMETERS
// ------------------

param apimSku string
param apimSubscriptionsConfig array = []

@description('Path segment for the Foundry API on APIM.')
param foundryApiPath string = 'foundry/hrpolicy'

@description('Path segment for the Bedrock API on APIM.')
param bedrockApiPath string = 'bedrock/expense'

@description('Log Analytics retention (days) for both the platform tables and the AIGatewayContent_CL custom table.')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 30

// ── Foundry backend ──────────────────────────────────────────────────────────
@description('Foundry project endpoint host + path, e.g. "<foundryResource>.services.ai.azure.com/api/projects/<projectName>". No scheme, no trailing slash.')
param foundryProjectEndpoint string

@description('Foundry deployed agent name (or model deployment name).')
param foundryAgentName string

// ── Amazon Bedrock backend ───────────────────────────────────────────────────
@description('AWS region for the Bedrock backend, e.g. "us-east-1".')
param bedrockRegion string = 'us-east-1'

@description('Bedrock inference profile model id, e.g. "us.amazon.nova-2-lite-v1:0".')
param bedrockModelId string = 'us.amazon.nova-2-lite-v1:0'

@secure()
@description('AWS IAM access key id with bedrock:InvokeModel permission. Stored as an APIM secure named value.')
param awsBedrockAccessKey string

@secure()
@description('AWS IAM secret access key. Stored as an APIM secure named value.')
param awsBedrockSecretKey string

// ── Purview + gateway service principal ──────────────────────────────────────
@description('Entra tenant id used for the on-behalf-of exchange in the Purview fragment.')
param graphTenantId string

@description('Gateway service principal client id (from the app registration created in the README prerequisites).')
param graphClientId string

@secure()
@description('Gateway service principal client secret. Stored as an APIM secure named value.')
param graphClientSecret string

@description('Purview processContent endpoint host, e.g. "graph.microsoft.com".')
param purviewGraphHost string = 'graph.microsoft.com'

// ── Granular RBAC on the audit table ─────────────────────────────────────────
@description('Object id of the single principal permitted to read AIGatewayContent_CL. Empty string skips the assignment (table + DCR still deployed).')
param contentLogReaderPrincipalId string = ''

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param contentLogReaderPrincipalType string = 'User'

@description('If false, both role assignments (APIM MI → Monitoring Metrics Publisher on the DCR, and optional Log Analytics Data Reader on the workspace) are skipped. Use false when the deploying identity lacks Microsoft.Authorization/roleAssignments/write; RBAC then has to be granted out-of-band.')
param enableRbacAssignments bool = true

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix    = uniqueString(subscription().id, resourceGroup().id)
var dceName           = 'dce-${resourceSuffix}'
var contentDcrName    = 'dcr-aigwcontent-${resourceSuffix}'
var contentTableName  = 'AIGatewayContent_CL'
var contentStreamName = 'Custom-${contentTableName}'

// Built-in role IDs
var monitoringMetricsPublisherRoleId = '3913510d-42f4-4e42-8a64-420c390055eb'
var logAnalyticsDataReaderRoleId     = '73c42c96-874c-492b-b04d-ab87d138a893'

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace ---------------------------------------------------
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

// 2. Application Insights ------------------------------------------------------
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawModule.outputs.id
    customMetricsOptedInType: 'WithDimensions'
  }
}

// 3. API Management ------------------------------------------------------------
module apimModule '../../modules/apim/v2/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: 'apim-${resourceSuffix}'
  dependsOn: [
    apimModule
  ]
}

// 4. AIGatewayContent_CL custom table -----------------------------------------
// Reference the LAW deployed by the workspaces.bicep module. The module names
// the workspace 'workspace-<resourceSuffix>' (see modules/operational-insights/v1),
// which we recompute here so the 'existing' reference is deploy-time-known.
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'workspace-${resourceSuffix}'
  dependsOn: [
    lawModule
  ]
}

resource contentTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: logWorkspace
  name: contentTableName
  properties: {
    plan: 'Analytics'
    retentionInDays: logRetentionDays
    schema: {
      name: contentTableName
      columns: [
        { name: 'TimeGenerated',      type: 'datetime' }
        { name: 'CorrelationId',      type: 'string'   }
        { name: 'RequestId',          type: 'string'   }
        { name: 'Direction',          type: 'string'   }
        { name: 'Backend',            type: 'string'   }
        { name: 'Model',              type: 'string'   }
        { name: 'ApiName',            type: 'string'   }
        { name: 'OperationName',      type: 'string'   }
        { name: 'User',               type: 'string'   }
        { name: 'SubscriptionId',     type: 'string'   }
        { name: 'InputTokens',        type: 'int'      }
        { name: 'OutputTokens',       type: 'int'      }
        { name: 'PurviewBlocked',     type: 'boolean'  }
        { name: 'PurviewBlockReason', type: 'string'   }
        { name: 'Content',            type: 'string'   }
      ]
    }
  }
}

// 5. Data Collection Endpoint --------------------------------------------------
resource dce 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' = {
  name: dceName
  location: resourceGroup().location
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// 6. Data Collection Rule → AIGatewayContent_CL --------------------------------
resource contentDcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: contentDcrName
  location: resourceGroup().location
  properties: {
    dataCollectionEndpointId: dce.id
    streamDeclarations: {
      '${contentStreamName}': {
        columns: [
          { name: 'TimeGenerated',      type: 'datetime' }
          { name: 'CorrelationId',      type: 'string'   }
          { name: 'RequestId',          type: 'string'   }
          { name: 'Direction',          type: 'string'   }
          { name: 'Backend',            type: 'string'   }
          { name: 'Model',              type: 'string'   }
          { name: 'ApiName',            type: 'string'   }
          { name: 'OperationName',      type: 'string'   }
          { name: 'User',               type: 'string'   }
          { name: 'SubscriptionId',     type: 'string'   }
          { name: 'InputTokens',        type: 'int'      }
          { name: 'OutputTokens',       type: 'int'      }
          { name: 'PurviewBlocked',     type: 'boolean'  }
          { name: 'PurviewBlockReason', type: 'string'   }
          { name: 'Content',            type: 'string'   }
        ]
      }
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logWorkspace.id
          name: 'aigwContentWorkspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          contentStreamName
        ]
        destinations: [
          'aigwContentWorkspace'
        ]
        transformKql: 'source'
        outputStream: contentStreamName
      }
    ]
  }
  dependsOn: [
    contentTable
  ]
}

// 7. APIM named values --------------------------------------------------------
resource nvGraphTenantId 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'graph-tenant-id'
  properties: {
    displayName: 'graph-tenant-id'
    value: graphTenantId
    secret: false
  }
}

resource nvGraphClientId 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'graph-client-id'
  properties: {
    displayName: 'graph-client-id'
    value: graphClientId
    secret: false
  }
}

resource nvGraphClientSecret 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'graph-client-secret'
  properties: {
    displayName: 'graph-client-secret'
    value: graphClientSecret
    secret: true
  }
}

resource nvPurviewHost 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'purview-graph-host'
  properties: {
    displayName: 'purview-graph-host'
    value: purviewGraphHost
    secret: false
  }
}

resource nvFoundryEndpoint 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'foundry-project-endpoint'
  properties: {
    displayName: 'foundry-project-endpoint'
    value: foundryProjectEndpoint
    secret: false
  }
}

resource nvFoundryAgent 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'foundry-agent-name'
  properties: {
    displayName: 'foundry-agent-name'
    value: foundryAgentName
    secret: false
  }
}

resource nvBedrockRegion 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'bedrock-region'
  properties: {
    displayName: 'bedrock-region'
    value: bedrockRegion
    secret: false
  }
}

resource nvBedrockModelId 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'bedrock-model-id'
  properties: {
    displayName: 'bedrock-model-id'
    value: bedrockModelId
    secret: false
  }
}

resource nvAwsAccessKey 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'aws-access-key'
  properties: {
    displayName: 'aws-access-key'
    value: awsBedrockAccessKey
    secret: true
  }
}

resource nvAwsSecretKey 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'aws-secret-key'
  properties: {
    displayName: 'aws-secret-key'
    value: awsBedrockSecretKey
    secret: true
  }
}

resource nvLogsContentIngestUrl 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'logs-content-ingest-url'
  properties: {
    displayName: 'logs-content-ingest-url'
    value: '${dce.properties.logsIngestion.endpoint}/dataCollectionRules/${contentDcr.properties.immutableId}/streams/${contentStreamName}?api-version=2023-01-01'
    secret: false
  }
}

// 8. APIM policy fragments ----------------------------------------------------
resource fragmentPurview 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'purview-processcontent'
  properties: {
    description: 'Shared Microsoft Purview processContent gate (uploadText inbound, downloadText outbound) with OBO-derived Graph token caching.'
    format: 'rawxml'
    value: loadTextContent('purview-processcontent.fragment.xml')
  }
  dependsOn: [
    nvGraphTenantId
    nvGraphClientId
    nvGraphClientSecret
    nvPurviewHost
  ]
}

resource fragmentEmitLog 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'emit-content-log'
  properties: {
    description: 'Shared fragment: post one prompt row and one response row to AIGatewayContent_CL via the Logs Ingestion API using APIM MI.'
    format: 'rawxml'
    value: loadTextContent('emit-content-log.fragment.xml')
  }
  dependsOn: [
    nvLogsContentIngestUrl
  ]
}

// 9. Foundry API + policy -----------------------------------------------------
resource foundryApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'foundry-hrpolicy'
  properties: {
    apiType: 'http'
    description: 'Foundry gpt-4.1 backend fronted by APIM with Purview DLP at Gate 1 (uploadText) and Gate 3 (downloadText).'
    displayName: 'Foundry HR Policy'
    format: 'openapi+json'
    path: foundryApiPath
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    type: 'http'
    value: string(loadJsonContent('../../modules/apim/v2/specs/PassThrough.json'))
  }
}

resource foundryApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: foundryApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('foundry-hrpolicy.policy.xml')
  }
  dependsOn: [
    fragmentPurview
    fragmentEmitLog
  ]
}

// API-level diagnostic — verbosity=verbose so <trace source="AIGateway">
// records are ingested into ApiManagementGatewayLogs.TraceRecords for the
// aigw-payg-purview-forecast KQL. Bound to the shared `azuremonitor` logger
// created by the platform apim module.
resource foundryApiDiagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: foundryApi
  name: 'azuremonitor'
  properties: {
    loggerId: resourceId('Microsoft.ApiManagement/service/loggers', apim.name, 'azuremonitor')
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

// 10. Bedrock API + policy ----------------------------------------------------
resource bedrockApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'bedrock-expense'
  properties: {
    apiType: 'http'
    description: 'Amazon Bedrock (Nova 2 Lite via bedrock-runtime.InvokeModel) fronted by APIM. SigV4 signed inside the policy. Same Purview DLP shape as the Foundry API.'
    displayName: 'Bedrock Expense'
    format: 'openapi+json'
    path: bedrockApiPath
    serviceUrl: 'https://bedrock-runtime.${bedrockRegion}.amazonaws.com'
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    type: 'http'
    value: string(loadJsonContent('../../modules/apim/v2/specs/PassThrough.json'))
  }
}

resource bedrockApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: bedrockApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('bedrock-expense.policy.xml')
  }
  dependsOn: [
    fragmentPurview
    fragmentEmitLog
  ]
}

resource bedrockApiDiagnostic 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: bedrockApi
  name: 'azuremonitor'
  properties: {
    loggerId: resourceId('Microsoft.ApiManagement/service/loggers', apim.name, 'azuremonitor')
    alwaysLog: 'allErrors'
    verbosity: 'verbose'
    logClientIp: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

// 11. Role: APIM MI → Monitoring Metrics Publisher on the content DCR ---------
resource apimIngestRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableRbacAssignments) {
  scope: contentDcr
  name: guid(contentDcr.id, apim.id, monitoringMetricsPublisherRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherRoleId)
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'Allow APIM system-assigned MI to POST records to AIGatewayContent_CL via the Logs Ingestion API.'
  }
}

// 12. Optional: granular RBAC on AIGatewayContent_CL --------------------------
// Grants Log Analytics Data Reader on the workspace with an ABAC condition
// restricting reads to the AIGatewayContent_CL table. If contentLogReaderPrincipalId
// is empty, skip the assignment (the table remains readable only by workspace admins).
resource contentReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableRbacAssignments && !empty(contentLogReaderPrincipalId)) {
  scope: logWorkspace
  name: guid(logWorkspace.id, contentLogReaderPrincipalId, logAnalyticsDataReaderRoleId, 'aigwcontent')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsDataReaderRoleId)
    principalId: contentLogReaderPrincipalId
    principalType: contentLogReaderPrincipalType
    description: 'Read-only access to the AIGatewayContent_CL custom table (ABAC-scoped).'
    conditionVersion: '2.0'
    condition: '((!(ActionMatches{\'Microsoft.OperationalInsights/workspaces/query/*/read\'})) OR (@Resource[Microsoft.OperationalInsights/workspaces/tables:name] StringEqualsIgnoreCase \'${contentTableName}\'))'
  }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.id
output applicationInsightsAppId string = appInsightsModule.outputs.appId
output apimServiceId string            = apim.id
output apimGatewayUrl string           = 'https://${apim.name}.azure-api.net'
output foundryApiPath string           = foundryApiPath
output bedrockApiPath string           = bedrockApiPath
output contentDcrImmutableId string    = contentDcr.properties.immutableId
output contentIngestUrl string         = '${dce.properties.logsIngestion.endpoint}/dataCollectionRules/${contentDcr.properties.immutableId}/streams/${contentStreamName}?api-version=2023-01-01'
