/**
 * @module event-hub-v1
 * @description This module defines the Event Hub resources using Bicep.
 * This is version 1 (v1) of the Event Hub module.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Event Hub namespace name')
param eventHubNamespaceName string

@description('Event Hub namespace location')
param eventHubLocation string = resourceGroup().location

@description('Event Hub SKU')
param eventHubSKU string = 'Standard'

@description('Event Hub SKU capacity')
param eventHubSKUCapacity int = 1

@description('Event Hub name')
param eventHubName string

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

// ------------------
//    RESOURCES
// ------------------

resource eventHubNamespaceResource 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: '${eventHubNamespaceName}-${resourceSuffix}'
  location: eventHubLocation
  sku: {
    name: eventHubSKU
    tier: eventHubSKU
    capacity: eventHubSKUCapacity
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}

resource eventHubResource 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: eventHubName
  parent: eventHubNamespaceResource
  properties: {
    messageRetentionInDays: 7
    partitionCount: 2
    status: 'Active'
  }
}

// ------------------
//    OUTPUTS
// ------------------

// output id string = logAnalytics.id
// output customerId string = logAnalytics.properties.customerId
