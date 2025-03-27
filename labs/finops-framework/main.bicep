// ------------------
//    PARAMETERS
// ------------------
param location string = resourceGroup().location

param currentUserObjectId string

param apimSku string
param openAIResourceLocation string = resourceGroup().location
param openAIDeployments array = []
param openAIAPIVersion string = '2024-02-01'

param apimSubscriptionsConfig array = []
param apimProductsConfig array = []
param apimUsersConfig array = []

// ------------------
//    VARIABLES
// ------------------
var logSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens' , 'x-ratelimit-remaining-requests' ]
  body: { bytes: 8192 }
}
var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

// ------------------
//    RESOURCES
// ------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'workspace-${resourceSuffix}'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource pricingTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: logAnalytics
  name: 'PRICING_CL'
  properties: {
    totalRetentionInDays: 4383
    plan: 'Analytics'
    schema: {
      name: 'PRICING_CL'
      description: 'OpenAI models pricing table for ${logAnalytics.properties.customerId}'
      
      columns: [
        {
          name: 'TimeGenerated'
          type: 'datetime'
        }
        {
          name: 'Model'
          type: 'string'
        }
        {
          name: 'InputTokensPrice'
          type: 'real'
        }
        {
          name: 'OutputTokensPrice'
          type: 'real'
        }
      ]
    }
    retentionInDays: 730
  }
}

resource pricingDCR 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-pricing-${resourceSuffix}'
  location: location
  kind: 'Direct'
  properties: {
    streamDeclarations: {
      'Custom-Json-${pricingTable.name}': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'Model'
            type: 'string'
          }
          {
            name: 'InputTokensPrice'
            type: 'real'
          }
          {
            name: 'OutputTokensPrice'
            type: 'real'
          }
        ]
      }
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalytics.id
          name: logAnalytics.name
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-Json-${pricingTable.name}'
        ]
        destinations: [
          logAnalytics.name
        ]
        transformKql: 'source'
        outputStream: 'Custom-${pricingTable.name}'
      }
    ]
  }
}

var monitoringMetricsPublisherRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')
resource pricingDCRRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: pricingDCR
  name: guid(subscription().id, resourceGroup().id, pricingDCR.name, monitoringMetricsPublisherRoleDefinitionID)
    properties: {
        roleDefinitionId: monitoringMetricsPublisherRoleDefinitionID
        principalId: currentUserObjectId
        principalType: 'User'
    }
}

resource subscriptionQuotaTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: logAnalytics
  name: 'SUBSCRIPTION_QUOTA_CL'
  properties: {
    totalRetentionInDays: 4383
    plan: 'Analytics'
    schema: {
      name: 'SUBSCRIPTION_QUOTA_CL'
      description: 'APIM subscriptions quota table for ${logAnalytics.properties.customerId}'
      columns: [
        {
          name: 'TimeGenerated'
          type: 'datetime'
        }
        {
          name: 'Subscription'
          type: 'string'
        }
        {
          name: 'CostQuota'
          type: 'real'
        }
      ]
    }
    retentionInDays: 730
  }
}

resource subscriptionQuotaDCR 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-quota-${resourceSuffix}'
  location: location
  kind: 'Direct'
  properties: {
    streamDeclarations: {
      'Custom-Json-${subscriptionQuotaTable.name}': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'Subscription'
            type: 'string'
          }
          {
            name: 'CostQuota'
            type: 'real'
          }
        ]
      }
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalytics.id
          name: logAnalytics.name
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-Json-${subscriptionQuotaTable.name}'
        ]
        destinations: [
          logAnalytics.name
        ]
        transformKql: 'source'
        outputStream: 'Custom-${subscriptionQuotaTable.name}'
      }
    ]
  }
}

resource subscriptionQuotaDCRRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: subscriptionQuotaDCR
  name: guid(subscription().id, resourceGroup().id, subscriptionQuotaDCR.name, monitoringMetricsPublisherRoleDefinitionID)
    properties: {
        roleDefinitionId: monitoringMetricsPublisherRoleDefinitionID
        principalId: currentUserObjectId
        principalType: 'User'
    }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'insights-${resourceSuffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    // BCP037: Not yet added to latest API: https://github.com/Azure/bicep-types-az/issues/2048
    #disable-next-line BCP037
    CustomMetricsOptedInType: 'WithDimensions'
  }
}

resource alertsWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, resourceSuffix, 'alertsWorkbook')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Alerts Workbook'
    serializedData: loadTextContent('workbooks/alerts.json')
    sourceId: logAnalytics.id
    category: 'workbook'
  }
}

resource azureOpenAIInsightsWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, resourceSuffix, 'azureOpenAIInsights')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Azure OpenAI Insights'
    serializedData: string(loadJsonContent('workbooks/azure-openai-insights.json'))
    sourceId: logAnalytics.id
    category: 'workbook'
  }
}

resource openAIUsageWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, resourceSuffix, 'costAnalysis')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Cost Analysis'
    serializedData: replace(replace(loadTextContent('workbooks/cost-analysis.json'), '{workspace-id}', logAnalytics.id), '{app-id}', applicationInsights.properties.AppId)
    sourceId: logAnalytics.id
    category: 'workbook'
  }
}

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: 'apim-${resourceSuffix}'
  location: location
  sku: {
    name: apimSku
    capacity: 1
  }
  properties: {
    publisherEmail: 'noreply@microsoft.com'
    publisherName: 'Microsoft'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource apimDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apim
  name: 'apiManagementDiagnosticSettings'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'GatewayLogs'
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

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: 'apim-logger'
  parent: apim
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: 'APIM Logger'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'openai-${resourceSuffix}'
  location: openAIResourceLocation
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
    customSubDomainName: toLower('openai-${resourceSuffix}')
  }
}

resource cognitiveServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' =  {
  name: '${cognitiveServices.name}-diagnostics'
  scope: cognitiveServices
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'Audit'
        enabled: true
      }      
      {
        category: 'RequestResponse'
        enabled: true
      }      
      {
        category: 'Trace'
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

@batchSize(1)
resource openAIDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for (deployment, i) in openAIDeployments: if(length(openAIDeployments) > 0) {
  name: openAIDeployments[i].name
  parent: cognitiveServices
  properties: {
    model: {
      format: 'OpenAI'
      name: openAIDeployments[i].model
      version: openAIDeployments[i].version
    }
  }
  sku: {
      name: openAIDeployments[i].sku
      capacity: openAIDeployments[i].capacity
  }
}]

var cognitiveServicesOpenAIUserRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cognitiveServices
  name: guid(subscription().id, resourceGroup().id, cognitiveServices.name, cognitiveServicesOpenAIUserRoleDefinitionID)
    properties: {
        roleDefinitionId: cognitiveServicesOpenAIUserRoleDefinitionID
        principalId: apim.identity.principalId
        principalType: 'ServicePrincipal'
    }
}


// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/apis
resource openAIAPI 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'openai'
  parent: apim
  properties: {
    apiType: 'http'
    description: 'OpenAI Inference API'
    displayName: 'OpenAI'
    format: 'openapi-link'
    path: 'openai'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/${openAIAPIVersion}/inference.json'
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: openAIAPI
  properties: {
    format: 'rawxml'
    value: loadTextContent('openai-policy.xml')
  }
}

resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' =  {
  name: 'openai-backend'
  parent: apim
  properties: {
    description: 'OpenAI backend'
    url: '${cognitiveServices.properties.endpoint}/openai'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 1
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT5M'
            statusCodeRanges: [
              {
                min: 429
                max: 429
              }
            ]
          }
          name: 'openAIBreakerRule'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
  }
}

resource openAIAPIDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: 'applicationinsights'
  parent: openAIAPI
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: apimLogger.id
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

@batchSize(1)
resource apimProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = [for product in apimProductsConfig: if(length(apimProductsConfig) > 0) {
  name: product.name
  parent: apim
  properties: {
    approvalRequired: true
    description: product.displayName
    displayName: product.displayName
    subscriptionRequired: true
    state: 'published'
  }
}]

@batchSize(1)
resource apimProductOpenAIAPI 'Microsoft.ApiManagement/service/products/apiLinks@2024-06-01-preview' = [for (product, i) in apimProductsConfig: if(length(apimProductsConfig) > 0) {
  parent: apimProduct[i]
  name: 'openai-${apimProduct[i].name}'
  properties: {
    apiId: openAIAPI.id
  }
}]

@batchSize(1)
resource productPolicy 'Microsoft.ApiManagement/service/products/policies@2024-06-01-preview' = [for (product, i) in apimProductsConfig: if(length(apimProductsConfig) > 0) {
  name: 'policy'
  parent: apimProduct[i]
  properties: {
    format: 'rawxml'
    value: replace(loadTextContent('products-policy.xml'), '{tokens-per-minute}', '${product.tpm}')
  }
}]

@batchSize(1)
resource apimUser 'Microsoft.ApiManagement/service/users@2024-06-01-preview' = [for (user, i) in apimUsersConfig: if(length(apimUsersConfig) > 0) {
  parent: apim
  name: user.name
  properties: {
    firstName: user.firstName
    lastName: user.lastName
    email: user.email
    state: 'active'
    identities: [
      {
        provider: 'Basic'
        id: user.email
      }
    ]
  }
}]

@batchSize(1)
resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = [for subscription in apimSubscriptionsConfig: if(length(apimSubscriptionsConfig) > 0) {
  name: subscription.name
  parent: apim
  properties: {
    allowTracing: true
    displayName: '${subscription.displayName}'
    scope: '/products/${subscription.product}'
    state: 'active'
  }
  dependsOn: [
    apimProduct
    productPolicy
  ]
}]

resource updateSubscriptionWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'la-update-sub-${resourceSuffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        When_an_Alert_is_Received: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                schemaId: {
                  type: 'string'
                }
                data: {
                  type: 'object'
                  properties: {
                    essentials: {
                      type: 'object'
                      properties: {
                        alertId: {
                          type: 'string'
                        }
                        alertRule: {
                          type: 'string'
                        }
                        targetResourceType: {
                          type: 'string'
                        }
                        alertRuleID: {
                          type: 'string'
                        }
                        severity: {
                          type: 'string'
                        }
                        signalType: {
                          type: 'string'
                        }
                        monitorCondition: {
                          type: 'string'
                        }
                        targetResourceGroup: {
                          type: 'string'
                        }
                        monitoringService: {
                          type: 'string'
                        }
                        alertTargetIDs: {
                          type: 'array'
                          items: {
                            type: 'string'
                          }
                        }
                        configurationItems: {
                          type: 'array'
                          items: {
                            type: 'string'
                          }
                        }
                        originAlertId: {
                          type: 'string'
                        }
                        firedDateTime: {
                          type: 'string'
                        }
                        description: {
                          type: 'string'
                        }
                        essentialsVersion: {
                          type: 'string'
                        }
                        alertContextVersion: {
                          type: 'string'
                        }
                        investigationLink: {
                          type: 'string'
                        }
                      }
                    }
                    alertContext: {
                      type: 'object'
                      properties: {
                        properties: {
                          type: 'object'
                          properties: {}
                        }
                        conditionType: {
                          type: 'string'
                        }
                        condition: {
                          type: 'object'
                          properties: {
                            windowSize: {
                              type: 'string'
                            }
                            allOf: {
                              type: 'array'
                              items: {
                                type: 'object'
                                properties: {
                                  searchQuery: {
                                    type: 'string'
                                  }
                                  metricMeasureColumn: {}
                                  targetResourceTypes: {
                                    type: 'string'
                                  }
                                  operator: {
                                    type: 'string'
                                  }
                                  threshold: {
                                    type: 'string'
                                  }
                                  timeAggregation: {
                                    type: 'string'
                                  }
                                  dimensions: {
                                    type: 'array'
                                    items: {
                                      type: 'object'
                                      properties: {
                                        name: {
                                          type: 'string'
                                        }
                                        value: {
                                          type: 'string'
                                        }
                                      }
                                      required: [
                                        'name'
                                        'value'
                                      ]
                                    }
                                  }
                                  metricValue: {
                                    type: 'integer'
                                  }
                                  failingPeriods: {
                                    type: 'object'
                                    properties: {
                                      numberOfEvaluationPeriods: {
                                        type: 'integer'
                                      }
                                      minFailingPeriodsToAlert: {
                                        type: 'integer'
                                      }
                                    }
                                  }
                                  linkToSearchResultsUI: {
                                    type: 'string'
                                  }
                                  linkToFilteredSearchResultsUI: {
                                    type: 'string'
                                  }
                                  linkToSearchResultsAPI: {
                                    type: 'string'
                                  }
                                  linkToFilteredSearchResultsAPI: {
                                    type: 'string'
                                  }
                                  event: {}
                                }
                                required: [
                                  'searchQuery'
                                  'metricMeasureColumn'
                                  'targetResourceTypes'
                                  'operator'
                                  'threshold'
                                  'timeAggregation'
                                  'dimensions'
                                  'metricValue'
                                  'failingPeriods'
                                  'linkToSearchResultsUI'
                                  'linkToFilteredSearchResultsUI'
                                  'linkToSearchResultsAPI'
                                  'linkToFilteredSearchResultsAPI'
                                  'event'
                                ]
                              }
                            }
                            windowStartTime: {
                              type: 'string'
                            }
                            windowEndTime: {
                              type: 'string'
                            }
                          }
                        }
                      }
                    }
                    customProperties: {
                      type: 'object'
                      properties: {}
                    }
                  }
                }
              }
            }
          }
        }
      }
      actions: {
        Update_APIM_Subscription_Status: {
          runAfter: {}
          type: 'Http'
          inputs: {
            uri: 'https://management.azure.com/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ApiManagement/service/${apim.name}/subscriptions/@{triggerBody()?[\'data\']?[\'alertContext\']?[\'condition\']?[\'allOf\']?[0]?[\'dimensions\']?[0]?[\'value\']}?api-version=2024-06-01-preview'
            method: 'PATCH'
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              properties: {
                state: '@if(contains(triggerBody()?[\'data\']?[\'essentials\']?[\'alertRule\'],\'suspend\'),\'suspended\',\'active\')'
              }
            }
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://management.azure.com/'
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {}
      }
    }
  }
}

resource workflowDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: updateSubscriptionWorkflow
  name: 'workflowDiagnosticSettings'
  properties: {
    workspaceId: logAnalytics.id
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

var apimServiceContributorRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '312a565d-c81f-4fd8-895a-4e21e48d571c')
resource apimRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: apim
  name: guid(subscription().id, resourceGroup().id, updateSubscriptionWorkflow.name, apimServiceContributorRoleDefinitionID)
    properties: {
        roleDefinitionId: apimServiceContributorRoleDefinitionID
        principalId: updateSubscriptionWorkflow.identity.principalId
        principalType: 'ServicePrincipal'
    }
}

resource actionGroupUpdateSub 'microsoft.insights/actionGroups@2024-10-01-preview' = {
  name: 'actiongroup-update-sub-${resourceSuffix}'
  location: 'Global'
  properties: {
    groupShortName: 'Update Sub'
    enabled: true
    emailReceivers: []
    smsReceivers: []
    webhookReceivers: []
    eventHubReceivers: []
    itsmReceivers: []
    azureAppPushReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: [
      {
        name: 'update-subscription-state'
        resourceId: updateSubscriptionWorkflow.id
        callbackUrl: '${updateSubscriptionWorkflow.listCallbackUrl().basePath}/triggers/When_an_Alert_is_Received/paths/invoke?api-version=${updateSubscriptionWorkflow.listCallbackUrl().queries['api-version']}&sp=${updateSubscriptionWorkflow.listCallbackUrl().queries.sp}&sv=${updateSubscriptionWorkflow.listCallbackUrl().queries.sv}&sig=${updateSubscriptionWorkflow.listCallbackUrl().queries.sig}'
        useCommonAlertSchema: true
      }
    ]
    azureFunctionReceivers: []
    armRoleReceivers: []
  }
}

resource ruleSuspendSub 'microsoft.insights/scheduledqueryrules@2024-01-01-preview' = {
  name: 'alert-suspend-sub-${resourceSuffix}'
  location: 'westeurope'
  kind: 'LogAlert'
  properties: {
    displayName: 'alert-suspend-subscriptions'
    severity: 3
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      logAnalytics.id
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'app(\'${applicationInsights.properties.AppId}\').customMetrics\n| where timestamp >= startofmonth(now()) and timestamp <= endofmonth(now())\n| where name == "Prompt Tokens" or name == "Completion Tokens"\n| extend SubscriptionName = tostring(customDimensions["Subscription ID"])\n| extend ProductName = tostring(customDimensions["Product"])\n| extend ModelName = tostring(customDimensions["Model"])\n| extend Region = tostring(customDimensions["Region"])\n| join kind=inner (\n    PRICING_CL\n    | summarize arg_max(TimeGenerated, *) by Model\n    | project Model, InputTokensPrice, OutputTokensPrice\n    )\n    on $left.ModelName == $right.Model\n| summarize\n    PromptTokens = sumif(value, name == "Prompt Tokens"),\n    CompletionTokens = sumif(value, name == "Completion Tokens")\n    by SubscriptionName, InputTokensPrice, OutputTokensPrice\n| extend InputCost = PromptTokens / 1000 * InputTokensPrice\n| extend OutputCost = CompletionTokens / 1000 * OutputTokensPrice\n| extend TotalCost = InputCost + OutputCost\n| summarize TotalCost = sum(TotalCost) by SubscriptionName\n| join kind=inner (\n    SUBSCRIPTION_QUOTA_CL\n    | summarize arg_max(TimeGenerated, *) by Subscription\n    | project Subscription, CostQuota\n) on $left.SubscriptionName == $right.Subscription\n| project SubscriptionName, CostQuota, TotalCost\n| where TotalCost > CostQuota\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'SubscriptionName'
              operator: 'Exclude'
              values: [
                'null'
              ]
            }
          ]
          operator: 'GreaterThan'
          threshold: json('0')
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [
        actionGroupUpdateSub.id
      ]
      customProperties: {}
      actionProperties: {}
    }
  }
}

resource ruleActivateSub 'microsoft.insights/scheduledqueryrules@2024-01-01-preview' = {
  name: 'alert-activate-sub-${resourceSuffix}'
  location: 'westeurope'
  kind: 'LogAlert'
  properties: {
    displayName: 'alert-activate-subscriptions'
    severity: 3
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      logAnalytics.id
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'app(\'${applicationInsights.properties.AppId}\').customMetrics\n| where timestamp >= startofmonth(now()) and timestamp <= endofmonth(now())\n| where name == "Prompt Tokens" or name == "Completion Tokens"\n| extend SubscriptionName = tostring(customDimensions["Subscription ID"])\n| extend ProductName = tostring(customDimensions["Product"])\n| extend ModelName = tostring(customDimensions["Model"])\n| extend Region = tostring(customDimensions["Region"])\n| join kind=inner (\n    PRICING_CL\n    | summarize arg_max(TimeGenerated, *) by Model\n    | project Model, InputTokensPrice, OutputTokensPrice\n    )\n    on $left.ModelName == $right.Model\n| summarize\n    PromptTokens = sumif(value, name == "Prompt Tokens"),\n    CompletionTokens = sumif(value, name == "Completion Tokens")\n    by SubscriptionName, InputTokensPrice, OutputTokensPrice\n| extend InputCost = PromptTokens / 1000 * InputTokensPrice\n| extend OutputCost = CompletionTokens / 1000 * OutputTokensPrice\n| extend TotalCost = InputCost + OutputCost\n| summarize TotalCost = sum(TotalCost) by SubscriptionName\n| join kind=inner (\n    SUBSCRIPTION_QUOTA_CL\n    | summarize arg_max(TimeGenerated, *) by Subscription\n    | project Subscription, CostQuota\n) on $left.SubscriptionName == $right.Subscription\n| project SubscriptionName, CostQuota, TotalCost\n| where TotalCost <= CostQuota\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'SubscriptionName'
              operator: 'Exclude'
              values: [
                'null'
              ]
            }
          ]
          operator: 'GreaterThan'
          threshold: json('0')
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [
        actionGroupUpdateSub.id
      ]
      customProperties: {}
      actionProperties: {}
    }
  }
}

module finOpsDashboardModule 'dashboard.bicep' = {
  name: 'finOpsDashboardModule'
  params: {
      resourceSuffix: resourceSuffix
      workspaceName: logAnalytics.name
      workspaceId: logAnalytics.id
      workbookCostAnalysisId: openAIUsageWorkbook.id
      workbookAzureOpenAIInsightsId: azureOpenAIInsightsWorkbook.id
      workspaceOpenAIDimenstion: 'openai'
      appInsightsId: applicationInsights.id
      appInsightsName: applicationInsights.name
      appInsightsAppId: applicationInsights.properties.AppId
    }
}


// ------------------
//    OUTPUTS
// ------------------

output applicationInsightsAppId string = applicationInsights.properties.AppId
output applicationInsightsName string = applicationInsights.name
output logAnalyticsWorkspaceId string = logAnalytics.properties.customerId
output apimServiceId string = apim.id
output apimResourceGatewayURL string = apim.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptions array = [for (subscription, i) in apimSubscriptionsConfig: {
  name: subscription.name
  displayName: subscription.displayName
  key: apimSubscription[i].listSecrets().primaryKey
}]

output pricingDCREndpoint string = pricingDCR.properties.endpoints.logsIngestion
output pricingDCRImmutableId string = pricingDCR.properties.immutableId
output pricingDCRStream string = pricingDCR.properties.dataFlows[0].streams[0]
output subscriptionQuotaDCREndpoint string = subscriptionQuotaDCR.properties.endpoints.logsIngestion
output subscriptionQuotaDCRImmutableId string = subscriptionQuotaDCR.properties.immutableId
output subscriptionQuotaDCRStream string = subscriptionQuotaDCR.properties.dataFlows[0].streams[0]
