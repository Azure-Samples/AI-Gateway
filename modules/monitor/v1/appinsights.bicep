/**
 * @module appinsights-v1
 * @description This module defines the Azure Application Insights (AppInsights) resources using Bicep.
 * This is version 1 (v1) of the AppInsights Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the Application Insights resource')
param applicationInsightsName string = 'insights'

@description('Location of the Application Insights resource')
param applicationInsightsLocation string = resourceGroup().location

@description('Name for the Workbook')
param workbookName string = 'OpenAIUsageAnalysis'

@description('Location for the Workbook')
param workbookLocation string = resourceGroup().location

@description('Display Name for the Workbook')
param workbookDisplayName string = 'OpenAI Usage Analysis'

@description('JSON string for the Workbook')
param workbookJson string

@description('Log Analytics Workspace Id')
param lawId string

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

// ------------------
//    RESOURCES
// ------------------

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${applicationInsightsName}-${resourceSuffix}'
  location: applicationInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: lawId
  }
}

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, workbookName)
  location: workbookLocation
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: workbookJson
    sourceId: applicationInsights.id
    category: 'OpenAI'
  }
}

// ------------------
//    OUTPUTS
// ------------------

output id string = applicationInsights.id
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
output appId string = applicationInsights.properties.AppId
