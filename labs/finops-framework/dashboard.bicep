param resourceSuffix string
param workspaceName string
param workspaceId string
param workbookCostAnalysisId string
param workbookAzureOpenAIInsightsId string
param workspaceOpenAIDimenstion string = 'openai'
param appInsightsId string
param appInsightsName string


resource finOpsDashboard 'Microsoft.Portal/dashboards@2022-12-01-preview' = {
  name: guid(resourceGroup().id, resourceSuffix, 'finOpsDashboard')
  location: resourceGroup().location
  tags: {
    'hidden-title': 'APIM❤️OpenAI- FinOps dashboard'
  }
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: {
              x: 0
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: []
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              settings: {
                content: {
                  settings: {
                    content: '<a href="https://github.com/Azure-Samples/AI-Gateway/blob/main/labs/finops-framework/finops-framework.ipynb" target="_blank"><img src="https://raw.githubusercontent.com/Azure-Samples/AI-Gateway/refs/heads/main/images/finops-framework-small.gif"/></a>'
                    markdownUri: null
                  }
                }
              }
            }
          }
          {
            position: {
              x: 6
              y: 0
              rowSpan: 2
              colSpan: 2
            }
            metadata: {
              inputs: [
                {
                  name: 'resourceGroup'
                  isOptional: true
                }
                {
                  name: 'id'
                  value: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/ResourceGroupMapPinnedPart'
            }
          }
          {
            position: {
              x: 8
              y: 0
              rowSpan: 4
              colSpan: 7
            }
            metadata: {
              inputs: [
                {
                  name: 'resourceTypeMode'
                  isOptional: true
                }
                {
                  name: 'ComponentId'
                  isOptional: true
                }
                {
                  name: 'Scope'
                  value: {
                    resourceIds: [
                      workspaceId
                    ]
                  }
                  isOptional: true
                }
                {
                  name: 'PartId'
                  value: '668e4656-5958-43bd-9521-6cec2114d304'
                  isOptional: true
                }
                {
                  name: 'Version'
                  value: '2.0'
                  isOptional: true
                }
                {
                  name: 'TimeRange'
                  value: 'P1D'
                  isOptional: true
                }
                {
                  name: 'DashboardId'
                  isOptional: true
                }
                {
                  name: 'DraftRequestParameters'
                  isOptional: true
                }
                {
                  name: 'Query'
                  value: 'AppMetrics\n| where TimeGenerated >= startofmonth(now()) and TimeGenerated <= endofmonth(now())\n| where Name == "Prompt Tokens" or Name == "Completion Tokens"\n| extend SubscriptionName = tostring(Properties["Subscription ID"])\n| extend ProductName = tostring(Properties["Product"])\n| extend ModelName = tostring(Properties["Model"])\n| extend Region = tostring(Properties["Region"])\n| join kind=inner (\n    PRICING_CL\n    | summarize arg_max(TimeGenerated, *) by Model\n    | project Model, InputTokensPrice, OutputTokensPrice\n    )\n    on $left.ModelName == $right.Model\n| summarize\n    PromptTokens = sumif(Sum, Name == "Prompt Tokens"),\n    CompletionTokens = sumif(Sum, Name == "Completion Tokens")\n    by SubscriptionName, InputTokensPrice, OutputTokensPrice\n| extend InputCost = PromptTokens / 1000 * InputTokensPrice\n| extend OutputCost = CompletionTokens / 1000 * OutputTokensPrice\n| extend TotalCost = InputCost + OutputCost\n| summarize TotalCost = sum(TotalCost) by SubscriptionName\n| join kind=inner (\n    SUBSCRIPTION_QUOTA_CL\n    | summarize arg_max(TimeGenerated, *) by Subscription\n    | project Subscription, CostQuota\n) on $left.SubscriptionName == $right.Subscription\n| project SubscriptionName, CostQuota, TotalCost\n\n'
                  isOptional: true
                }
                {
                  name: 'ControlType'
                  value: 'FrameControlChart'
                  isOptional: true
                }
                {
                  name: 'SpecificChart'
                  value: 'UnstackedColumn'
                  isOptional: true
                }
                {
                  name: 'PartTitle'
                  value: 'Analytics'
                  isOptional: true
                }
                {
                  name: 'PartSubTitle'
                  value: workspaceName
                  isOptional: true
                }
                {
                  name: 'Dimensions'
                  value: {
                    xAxis: {
                      name: 'SubscriptionName'
                      type: 'string'
                    }
                    yAxis: [
                      {
                        name: 'CostQuota'
                        type: 'real'
                      }
                      {
                        name: 'TotalCost'
                        type: 'real'
                      }
                    ]
                    splitBy: []
                    aggregation: 'Sum'
                  }
                  isOptional: true
                }
                {
                  name: 'LegendOptions'
                  value: {
                    isEnabled: true
                    position: 'Bottom'
                  }
                  isOptional: true
                }
                {
                  name: 'IsQueryContainTimeRange'
                  value: true
                  isOptional: true
                }
              ]
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              settings: {}
            }
          }
          {
            position: {
              x: 6
              y: 2
              rowSpan: 1
              colSpan: 2
            }
            metadata: {
              inputs: [
                {
                  name: 'ComponentId'
                  value: {
                    SubscriptionId: subscription().subscriptionId
                    ResourceGroup: resourceGroup().name
                    Name: workspaceName
                    LinkedApplicationType: 2
                    ResourceId: workspaceId
                    ResourceType: 'microsoft.operationalinsights/workspaces'
                    IsAzureFirst: false
                  }
                }
                {
                  name: 'ResourceIds'
                  value: [
                    workspaceId
                  ]
                  isOptional: true
                }
                {
                  name: 'Type'
                  value: 'workbook'
                  isOptional: true
                }
                {
                  name: 'TimeContext'
                  isOptional: true
                }
                {
                  name: 'ConfigurationId'
                  value: workbookCostAnalysisId
                  isOptional: true
                }
                {
                  name: 'ViewerMode'
                  value: false
                  isOptional: true
                }
                {
                  name: 'GalleryResourceType'
                  value: 'microsoft.operationalinsights/workspaces'
                  isOptional: true
                }
                {
                  name: 'NotebookParams'
                  isOptional: true
                }
                {
                  name: 'Location'
                  value: resourceGroup().location
                  isOptional: true
                }
                {
                  name: 'Version'
                  value: '1.0'
                  isOptional: true
                }
              ]
              type: 'Extension/AppInsightsExtension/PartType/NotebookPinnedPart'
            }
          }
          {
            position: {
              x: 6
              y: 3
              rowSpan: 1
              colSpan: 2
            }
            metadata: {
              inputs: [
                {
                  name: 'ComponentId'
                  value: {
                    SubscriptionId: subscription().subscriptionId
                    ResourceGroup: resourceGroup().name
                    Name: workspaceName
                    LinkedApplicationType: 2
                    ResourceId: workspaceId
                    ResourceType: 'microsoft.operationalinsights/workspaces'
                    IsAzureFirst: false
                  }
                }
                {
                  name: 'ResourceIds'
                  value: [
                    workspaceId
                  ]
                  isOptional: true
                }
                {
                  name: 'Type'
                  value: 'workbook'
                  isOptional: true
                }
                {
                  name: 'TimeContext'
                  isOptional: true
                }
                {
                  name: 'ConfigurationId'
                  value: workbookAzureOpenAIInsightsId
                  isOptional: true
                }
                {
                  name: 'ViewerMode'
                  value: false
                  isOptional: true
                }
                {
                  name: 'GalleryResourceType'
                  value: 'microsoft.operationalinsights/workspaces'
                  isOptional: true
                }
                {
                  name: 'NotebookParams'
                  value: '{"Subscription":["/subscriptions/9d4a14de-67d7-4029-a3b4-7a7e3e6581cf"],"Resources":["value::all"],"TimeRange":{"durationMs":2592000000},"Message":"# 8 / 10","ResourceName":"Azure OpenAI Service"}'
                  isOptional: true
                }
                {
                  name: 'Location'
                  value: resourceGroup().location
                  isOptional: true
                }
                {
                  name: 'Version'
                  value: '1.0'
                  isOptional: true
                }
              ]
              type: 'Extension/AppInsightsExtension/PartType/NotebookPinnedPart'
            }
          }
          {
            position: {
              x: 0
              y: 4
              rowSpan: 4
              colSpan: 7
            }
            metadata: {
              inputs: [
                {
                  name: 'resourceTypeMode'
                  isOptional: true
                }
                {
                  name: 'ComponentId'
                  isOptional: true
                }
                {
                  name: 'Scope'
                  value: {
                    resourceIds: [
                      workspaceId
                    ]
                  }
                  isOptional: true
                }
                {
                  name: 'PartId'
                  value: '9f74de47-50f9-41b8-b15e-5466807c7eaa'
                  isOptional: true
                }
                {
                  name: 'Version'
                  value: '2.0'
                  isOptional: true
                }
                {
                  name: 'TimeRange'
                  isOptional: true
                }
                {
                  name: 'DashboardId'
                  isOptional: true
                }
                {
                  name: 'DraftRequestParameters'
                  isOptional: true
                }
                {
                  name: 'Query'
                  value: 'AppMetrics\n| where TimeGenerated >= startofmonth(now()) and TimeGenerated <= endofmonth(now())\n| where Name == "Prompt Tokens" or Name == "Completion Tokens"\n| extend SubscriptionName = tostring(Properties["Subscription ID"])\n| extend ProductName = tostring(Properties["Product"])\n| extend ModelName = tostring(Properties["Model"])\n| extend Region = tostring(Properties["Region"])\n| join kind=inner (\n    PRICING_CL\n    | summarize arg_max(TimeGenerated, *) by Model\n    | project Model, InputTokensPrice, OutputTokensPrice\n    )\n    on $left.ModelName == $right.Model\n| summarize\n    PromptTokens = sumif(Sum, Name == "Prompt Tokens"),\n    CompletionTokens = sumif(Sum, Name == "Completion Tokens")\n    by SubscriptionName, InputTokensPrice, OutputTokensPrice\n| extend InputCost = PromptTokens / 1000 * InputTokensPrice\n| extend OutputCost = CompletionTokens / 1000 * OutputTokensPrice\n| extend TotalCost = InputCost + OutputCost\n| summarize TotalCost = sum(TotalCost) by SubscriptionName\n| project SubscriptionName, TotalCost\n\n'
                  isOptional: true
                }
                {
                  name: 'ControlType'
                  value: 'FrameControlChart'
                  isOptional: true
                }
                {
                  name: 'SpecificChart'
                  value: 'Donut'
                  isOptional: true
                }
                {
                  name: 'PartTitle'
                  value: 'Analytics'
                  isOptional: true
                }
                {
                  name: 'PartSubTitle'
                  value: workspaceName
                  isOptional: true
                }
                {
                  name: 'Dimensions'
                  value: {
                    xAxis: {
                      name: 'SubscriptionName'
                      type: 'string'
                    }
                    yAxis: [
                      {
                        name: 'TotalCost'
                        type: 'real'
                      }
                    ]
                    splitBy: []
                    aggregation: 'Sum'
                  }
                  isOptional: true
                }
                {
                  name: 'LegendOptions'
                  value: {
                    isEnabled: true
                    position: 'Bottom'
                  }
                  isOptional: true
                }
                {
                  name: 'IsQueryContainTimeRange'
                  value: true
                  isOptional: true
                }
              ]
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              settings: {}
            }
          }
          {
            position: {
              x: 7
              y: 4
              rowSpan: 4
              colSpan: 8
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appInsightsId
                          }
                          name: 'Total Tokens'
                          aggregationType: 1
                          namespace: workspaceOpenAIDimenstion
                          metricVisualization: {
                            displayName: 'Total Tokens'
                          }
                        }
                      ]
                      title: 'Total Tokens consumed by subscription'
                      titleKind: 1
                      visualization: {
                        chartType: 3
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      grouping: {
                        dimension: [
                          'Subscription ID'
                          'Product'
                        ]
                        sort: 2
                        top: 10
                      }
                      timespan: {
                        relative: {
                          duration: 14400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 0
              y: 8
              rowSpan: 3
              colSpan: 5
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appInsightsId
                          }
                          name: 'requests/count'
                          aggregationType: 7
                          namespace: 'microsoft.insights/components'
                          metricVisualization: {
                            displayName: 'Server requests'
                            resourceDisplayName: appInsightsName
                            color: '#0078D4'
                          }
                        }
                      ]
                      title: 'Server requests'
                      titleKind: 2
                      visualization: {
                        chartType: 3
                      }
                      openBladeOnClick: {
                        openBlade: true
                        destinationBlade: {
                          bladeName: 'ResourceMenuBlade'
                          parameters: {
                            id: appInsightsId
                            menuid: 'performance'
                          }
                          extensionName: 'HubsExtension'
                          options: {
                            parameters: {
                              id: appInsightsId
                              menuid: 'performance'
                            }
                          }
                        }
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 5
              y: 8
              rowSpan: 3
              colSpan: 5
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appInsightsId
                          }
                          name: 'requests/duration'
                          aggregationType: 4
                          namespace: 'microsoft.insights/components'
                          metricVisualization: {
                            displayName: 'Server response time'
                            resourceDisplayName: appInsightsName
                            color: '#0078D4'
                          }
                        }
                      ]
                      title: 'Server response time'
                      titleKind: 2
                      visualization: {
                        chartType: 2
                      }
                      openBladeOnClick: {
                        openBlade: true
                        destinationBlade: {
                          bladeName: 'ResourceMenuBlade'
                          parameters: {
                            id: appInsightsId
                            menuid: 'performance'
                          }
                          extensionName: 'HubsExtension'
                          options: {
                            parameters: {
                              id: appInsightsId
                              menuid: 'performance'
                            }
                          }
                        }
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 10
              y: 8
              rowSpan: 3
              colSpan: 5
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appInsightsId
                          }
                          name: 'requests/failed'
                          aggregationType: 7
                          namespace: 'microsoft.insights/components'
                          metricVisualization: {
                            displayName: 'Failed requests'
                            resourceDisplayName: appInsightsName
                            color: '#EC008C'
                          }
                        }
                      ]
                      title: 'Failed requests'
                      titleKind: 2
                      visualization: {
                        chartType: 3
                      }
                      openBladeOnClick: {
                        openBlade: true
                        destinationBlade: {
                          bladeName: 'ResourceMenuBlade'
                          parameters: {
                            id: appInsightsId
                            menuid: 'failures'
                          }
                          extensionName: 'HubsExtension'
                          options: {
                            parameters: {
                              id: appInsightsId
                              menuid: 'failures'
                            }
                          }
                        }
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
        ]
      }
    ]
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
        filterLocale: {
          value: 'en-us'
        }
        filters: {
          value: {
            MsPortalFx_TimeRange: {
              model: {
                format: 'utc'
                granularity: '30m'
                relative: '12h'
              }
              displayCache: {
                name: 'UTC Time'
                value: 'Past 12 hours'
              }
              filteredPartIds: [
                'StartboardPart-LogsDashboardPart-2ac7586a-f1c8-451e-98c8-c5be89eb5894'
                'StartboardPart-MonitorChartPart-2ac7586a-f1c8-451e-98c8-c5be89eb589a'
                'StartboardPart-MonitorChartPart-2ac7586a-f1c8-451e-98c8-c5be89eb589c'
                'StartboardPart-MonitorChartPart-2ac7586a-f1c8-451e-98c8-c5be89eb589e'
                'StartboardPart-MonitorChartPart-2ac7586a-f1c8-451e-98c8-c5be89eb58a0'
                'StartboardPart-LogsDashboardPart-2ac7586a-f1c8-451e-98c8-c5be89eb58a2'
              ]
            }
          }
        }
      }
    }
  }
}
