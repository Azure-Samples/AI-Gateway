// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorEndpointName string = 'afd-${uniqueString(resourceGroup().id)}'

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Premium_AzureFrontDoor'

@description('The FQDN of the Service to use as the backend for the Front Door.')
param backendHostName string = ''

@description('The name of the Private Link Service to use as the backend for the Front Door.')
param privateLinkBackendId string = ''

// ------------------
//    VARIABLES
// ------------------

var frontDoorProfileName = 'FrontDoor'
var frontDoorOriginGroupName = 'OriginGroup'
var frontDoorOriginName = 'FrontDoorOrigin'
var frontDoorRouteName = 'FrontDoorRoute'

// ------------------
//    RESOURCES
// ------------------

resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 60
    }
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: frontDoorOriginName
  parent: frontDoorOriginGroup
  properties: {
    hostName: backendHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: backendHostName
    priority: 1
    weight: 1000
    enabledState: 'Enabled'

    sharedPrivateLinkResource: {
      privateLink: {
        id: privateLinkBackendId
      }
      groupId: 'Gateway'
      privateLinkLocation: resourceGroup().location
      requestMessage: 'Please validate PE connection'
    }
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: ['Http', 'Https']
    patternsToMatch: ['/*']
    forwardingProtocol: 'MatchRequest' // 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    originPath: '/'
  }
}

output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
