// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
param apimProductsConfig array = []
param apimUsersConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference' // Path to the inference API in the APIM service
param foundryProjectName string = 'default'

// ------------------
//    VARIABLES
// ------------------
var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)


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
module apimModule '../../modules/apim/v2/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 4. AI Foundry
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
    name: 'foundryModule'
    params: {
      aiServicesConfig: aiServicesConfig
      modelsConfig: modelsConfig
      apimPrincipalId: apimModule.outputs.principalId
      foundryProjectName: foundryProjectName
    }
  }

// 5. APIM Inference API
module inferenceAPIModule '../../modules/apim/v2/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}



resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'workspace-${resourceSuffix}'
  dependsOn: [
    inferenceAPIModule
  ]
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: 'insights-${resourceSuffix}'
  dependsOn: [
    inferenceAPIModule
  ]
}

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: 'apim-${resourceSuffix}'
  dependsOn: [
    inferenceAPIModule
  ]
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
  location: resourceGroup().location
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
        principalId: deployer().objectId
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
  location: resourceGroup().location
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
        principalId: deployer().objectId
        principalType: 'User'
    }
}


resource alertsWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, resourceSuffix, 'alertsWorkbook')
  location: resourceGroup().location
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
  location: resourceGroup().location
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
  location: resourceGroup().location
  kind: 'shared'
  properties: {
    displayName: 'Cost Analysis'
    serializedData: replace(loadTextContent('workbooks/cost-analysis.json'), '{workspace-id}', logAnalytics.id)
    sourceId: logAnalytics.id
    category: 'workbook'
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
resource apimProductInferenceAPI 'Microsoft.ApiManagement/service/products/apiLinks@2024-06-01-preview' = [for (product, i) in apimProductsConfig: if(length(apimProductsConfig) > 0) {
  parent: apimProduct[i]
  name: 'openai-${apimProduct[i].name}'
  properties: {
    apiId: inferenceAPIModule.outputs.apiId
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
resource apimSubscriptions 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = [for subscription in apimSubscriptionsConfig: if(length(apimSubscriptionsConfig) > 0) {
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
  location: resourceGroup().location
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

resource ruleSuspendSub 'microsoft.insights/scheduledqueryrules@2025-01-01-preview' = {
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
          query: 'let llmHeaderLogs = ApiManagementGatewayLlmLog\n    | where TimeGenerated >= startofmonth(now()) and TimeGenerated <= endofmonth(now())\n    | where DeploymentName != \'\';\nlet llmLogsWithSubscriptionId = llmHeaderLogs\n    | join kind=leftouter ApiManagementGatewayLogs on CorrelationId\n    | project\n        SubscriptionName = ApimSubscriptionId,\n        DeploymentName,\n        PromptTokens,\n        CompletionTokens,\n        TotalTokens;\nllmLogsWithSubscriptionId\n| join kind=inner (\n    PRICING_CL\n    | summarize arg_max(TimeGenerated, *) by Model\n    | project Model, InputTokensPrice, OutputTokensPrice\n    )\n    on $left.DeploymentName == $right.Model\n| extend InputCost = PromptTokens * InputTokensPrice\n| extend OutputCost = CompletionTokens * OutputTokensPrice\n| summarize\n    InputCost = sum(InputCost),\n    OutputCost = sum(OutputCost)\n    by SubscriptionName\n| extend TotalCost = (InputCost + OutputCost) / 1000\n| join kind=inner (\n    SUBSCRIPTION_QUOTA_CL\n    | summarize arg_max(TimeGenerated, *) by Subscription\n    | project Subscription, CostQuota\n    )\n    on $left.SubscriptionName == $right.Subscription\n| project SubscriptionName, CostQuota, TotalCost\n| where TotalCost > CostQuota\n'
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

resource ruleActivateSub 'microsoft.insights/scheduledqueryrules@2025-01-01-preview' = {
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
          query: 'let llmHeaderLogs = ApiManagementGatewayLlmLog\n    | where TimeGenerated >= startofmonth(now()) and TimeGenerated <= endofmonth(now())\n    | where DeploymentName != \'\';\nlet llmLogsWithSubscriptionId = llmHeaderLogs\n    | join kind=leftouter ApiManagementGatewayLogs on CorrelationId\n    | project\n        SubscriptionName = ApimSubscriptionId,\n        DeploymentName,\n        PromptTokens,\n        CompletionTokens,\n        TotalTokens;\nllmLogsWithSubscriptionId\n| join kind=inner (\n    PRICING_CL\n    | summarize arg_max(TimeGenerated, *) by Model\n    | project Model, InputTokensPrice, OutputTokensPrice\n    )\n    on $left.DeploymentName == $right.Model\n| extend InputCost = PromptTokens * InputTokensPrice\n| extend OutputCost = CompletionTokens * OutputTokensPrice\n| summarize\n    InputCost = sum(InputCost),\n    OutputCost = sum(OutputCost)\n    by SubscriptionName\n| extend TotalCost = (InputCost + OutputCost) / 1000\n| join kind=inner (\n    SUBSCRIPTION_QUOTA_CL\n    | summarize arg_max(TimeGenerated, *) by Subscription\n    | project Subscription, CostQuota\n    )\n    on $left.SubscriptionName == $right.Subscription\n| project SubscriptionName, CostQuota, TotalCost\n| where TotalCost <= CostQuota\n'
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
      appInsightsId: applicationInsights.id
      appInsightsName: applicationInsights.name
    }
}


// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptions array = [for (subscription, i) in apimSubscriptionsConfig: {
  name: subscription.name
  displayName: subscription.displayName
  key: apimSubscriptions[i].listSecrets().primaryKey
}]

output pricingDCREndpoint string = pricingDCR.properties.endpoints.logsIngestion
output pricingDCRImmutableId string = pricingDCR.properties.immutableId
output pricingDCRStream string = pricingDCR.properties.dataFlows[0].streams[0]
output subscriptionQuotaDCREndpoint string = subscriptionQuotaDCR.properties.endpoints.logsIngestion
output subscriptionQuotaDCRImmutableId string = subscriptionQuotaDCR.properties.immutableId
output subscriptionQuotaDCRStream string = subscriptionQuotaDCR.properties.dataFlows[0].streams[0]

