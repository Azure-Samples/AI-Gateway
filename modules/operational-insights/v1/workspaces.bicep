/**
 * @module workspaces-v1
 * @description This module defines the Azure Log Analytics Workspaces (LAW) resources using Bicep.
 * This is version 1 (v1) of the LAW Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('The suffix to append to the Log Analytics name. Defaults to a unique string based on subscription and resource group IDs.')
param resourceSuffix string = uniqueString(subscription().id, resourceGroup().id)

@description('Name of the Log Analytics resource. Defaults to "workspace-<resourceSuffix>".')
param logAnalyticsName string = 'workspace-${resourceSuffix}'

@description('Location of the Log Analytics resource')
param logAnalyticsLocation string = resourceGroup().location

// ------------------
//    VARIABLES
// ------------------

// ------------------
//    RESOURCES
// ------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
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
  identity: {
    type: 'SystemAssigned'
  }
}

// ------------------
//    OUTPUTS
// ------------------

output id string = logAnalytics.id
output name string = logAnalytics.name
output customerId string = logAnalytics.properties.customerId

#disable-next-line outputs-should-not-contain-secrets
output primarySharedKey string = logAnalytics.listKeys().primarySharedKey
