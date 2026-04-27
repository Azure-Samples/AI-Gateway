param resourceSuffix string
param workspaceName string
param workspaceId string
param workbookId string
param appInsightsId string
param appInsightsName string


resource mcpInsightsDashboard 'Microsoft.Portal/dashboards@2022-12-01-preview' = {
  name: guid(resourceGroup().id, resourceSuffix, 'mcpInsightsDashboard')
  location: resourceGroup().location
  tags: {
    'hidden-title': 'APIM❤️MCP dashboard'
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
                    content: '<a href="https://github.com/Azure-Samples/AI-Gateway/blob/main/labs/mcp-from-api/mcp-from-api.ipynb" target="_blank"><img src="https://raw.githubusercontent.com/Azure-Samples/AI-Gateway/refs/heads/main/images/model-context-protocol-small.gif"/></a>'
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
                      appInsightsId
                    ]
                  }
                  isOptional: true
                }
                {
                  name: 'PartId'
                  value: '46ea6a83-4646-4bc4-af13-735bb279c86a'
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
                  value: 'requests\n| join kind=leftouter (\n    traces\n    | project traceMessage=message, operation_Id, agentId = customDimensions["agent-id"], userId = customDimensions["user-id"]\n) on operation_Id\n| extend apiName = tostring(customDimensions["API Name"])\n| extend resultCode = extract(@"(\\d+)", 1, resultCode)\n| where customDimensions["API Type"] == "mcp"\n| summarize RecordCount = count() by tostring(agentId)\n\n'
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
                  value: 'Agent Insights'
                  isOptional: true
                }
                {
                  name: 'PartSubTitle'
                  value: 'Distribution of requests by Agent Id'
                  isOptional: true
                }
                {
                  name: 'Dimensions'
                  value: {
                    xAxis: {
                      name: 'agentId'
                      type: 'string'
                    }
                    yAxis: [
                      {
                        name: 'RecordCount'
                        type: 'long'
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
                  value: false
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
                    ResourceId: appInsightsId
                    ResourceType: 'microsoft.insights/components'
                    IsAzureFirst: false
                  }
                }
                {
                  name: 'ResourceIds'
                  value: [
                    appInsightsId
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
                  value: workbookId
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
                      appInsightsId
                    ]
                  }
                  isOptional: true
                }
                {
                  name: 'PartId'
                  value: '9c0aeaed-5f51-4156-913b-2f965e8fb327'
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
                  value: 'requests\n| join kind=leftouter (\n    traces\n    | project traceMessage=message, operation_Id, agentId = customDimensions["agent-id"], userId = customDimensions["user-id"]\n) on operation_Id\n| extend apiName = tostring(customDimensions["API Name"])\n| extend resultCode = extract(@"(\\d+)", 1, resultCode)\n| where customDimensions["API Type"] == "mcp"\n| summarize RecordCount = count() by apiName, bin(timestamp, 1m)\n\n'
                  isOptional: true
                }
                {
                  name: 'ControlType'
                  value: 'FrameControlChart'
                  isOptional: true
                }
                {
                  name: 'SpecificChart'
                  value: 'StackedColumn'
                  isOptional: true
                }
                {
                  name: 'PartTitle'
                  value: 'MCP Tools Requests'
                  isOptional: true
                }
                {
                  name: 'PartSubTitle'
                  value: 'Requests by MCP Tools'
                  isOptional: true
                }
                {
                  name: 'Dimensions'
                  value: {
                    xAxis: {
                      name: 'timestamp'
                      type: 'datetime'
                    }
                    yAxis: [
                      {
                        name: 'RecordCount'
                        type: 'long'
                      }
                    ]
                    splitBy: [
                      {
                        name: 'apiName'
                        type: 'string'
                      }
                    ]
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
                  value: false
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
                      appInsightsId
                    ]
                  }
                  isOptional: true
                }
                {
                  name: 'PartId'
                  value: '8e3f9625-d658-4ea5-87a2-401b533e3f58'
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
                  value: 'requests\n| join kind=leftouter (\n    traces\n    | project traceMessage=message, operation_Id, agentId = customDimensions["agent-id"], userId = customDimensions["user-id"]\n) on operation_Id\n| extend apiName = tostring(customDimensions["API Name"])\n| extend resultCode = extract(@"(\\d+)", 1, resultCode)\n| where customDimensions["API Type"] == "mcp"\n| summarize duration = avg(duration) by apiName, bin(timestamp, 1m)\n\n'
                  isOptional: true
                }
                {
                  name: 'ControlType'
                  value: 'FrameControlChart'
                  isOptional: true
                }
                {
                  name: 'SpecificChart'
                  value: 'StackedColumn'
                  isOptional: true
                }
                {
                  name: 'PartTitle'
                  value: 'MCP Tools Performance'
                  isOptional: true
                }
                {
                  name: 'PartSubTitle'
                  value: 'Duration of requests by MCP Tool'
                  isOptional: true
                }
                {
                  name: 'Dimensions'
                  value: {
                    xAxis: {
                      name: 'timestamp'
                      type: 'datetime'
                    }
                    yAxis: [
                      {
                        name: 'duration'
                        type: 'real'
                      }
                    ]
                    splitBy: [
                      {
                        name: 'apiName'
                        type: 'string'
                      }
                    ]
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
                  value: false
                  isOptional: true
                }
              ]
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              settings: {}
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
