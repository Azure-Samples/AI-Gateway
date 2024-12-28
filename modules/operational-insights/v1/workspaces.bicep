/**
 * @module workspaces-v1
 * @description This module defines the Azure Log Analytics Workspaces (LAW) resources using Bicep.
 * This is version 1 (v1) of the LAW Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the Log Analytics resource. Defaults to "workspace".')
param logAnalyticsName string = 'workspace'

@description('Location of the Log Analytics resource')
param logAnalyticsLocation string = resourceGroup().location

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

// ------------------
//    RESOURCES
// ------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${logAnalyticsName}-${resourceSuffix}'
  location: logAnalyticsLocation
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

// ------------------
//    OUTPUTS
// ------------------

output id string = logAnalytics.id
output customerId string = logAnalytics.properties.customerId
