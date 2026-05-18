/*
Application Insights Module
----------------------------
Creates a Log Analytics workspace and Application Insights resource,
then connects App Insights to the Foundry account for agent tracing.

Pattern follows: 01-connections/connection-application-insights.bicep
*/

@description('Azure region for the deployment')
param location string

@description('Name of the AI Foundry account')
param accountName string

@description('Name for the Application Insights resource')
param appInsightsName string

@description('Name for the Log Analytics workspace')
param logAnalyticsName string = '${appInsightsName}-law'

// ---- Log Analytics Workspace ----
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ---- Application Insights (workspace-based) ----
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// ---- Connect App Insights to Foundry account ----
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
  scope: resourceGroup()
}

resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: appInsightsName
  parent: account
  properties: {
    category: 'AppInsights'
    target: appInsights.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: appInsights.properties.ConnectionString
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsights.id
    }
  }
}

output appInsightsName string = appInsights.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
