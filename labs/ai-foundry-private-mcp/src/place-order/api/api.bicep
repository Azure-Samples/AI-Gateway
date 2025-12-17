param apimServiceName string
param apicServiceName string
param apiPath string = 'order'
param apiName string = 'order-api'
param apiDisplayName string = 'Place Order API'
param apiDescription string = 'API for placing orders'

param environmentName string
param apiLifecycleStage string = 'development'

param apiContactName string = 'Alex'
param apiContactEmail string = 'alex@example.com'
param apiContactUrl string = 'https://example.com/docs/${apiPath}'
param apiVersionName string = '1-0-0'
param apiVersionDisplayName string = '1.0.0'
param apiDefinitionName string = '${apiName}-definition'
param apiDefinitionDisplayName string = '${apiDisplayName} Definition'
param apiDefinitionDescription string = '${apiDisplayName} Definition for version ${apiVersionName}'

param apiDeploymentName string = '${apiName}-deployment'
param apiDeploymentDisplayName string = '${apiDisplayName} Deployment'
param apiDeploymentDescription string = '${apiDisplayName} Deployment for version ${apiVersionName} and environment ${environmentName}'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)


resource placeOrderWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'ordersworkflow-${resourceSuffix}'
  location: resourceGroup().location
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
        PlaceOrder: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                sku: {
                  type: 'string'
                }
                quantity: {
                  type: 'integer'
                }
              }
            }
          }
          description: 'Place an Order to the specified sku and quantity.'
        }
      }
      actions: {
        Condition: {
          actions: {
            UpdateStatusOk: {
              type: 'Response'
              kind: 'Http'
              inputs: {
                statusCode: 200
                body: {
                  status: '@concat(\'Order placed with id \', rand(1000,9000),\' for SKU \', triggerBody()?[\'sku\'], \' with \', triggerBody()?[\'quantity\'], \' items.\')'                  
                }
              }
              description: 'Return the status for the order.'
            }
          }
          runAfter: {}
          else: {
            actions: {
              UpdateStatusError: {
                type: 'Response'
                kind: 'Http'
                inputs: {
                  statusCode: 200
                  body: {
                    status: 'The order was not placed because the quantity exceeds the maximum limit of five items.'
                  }
                }
                description: 'Return the status for the order.'
              }
            }
          }
          expression: {
            and: [
              {
                lessOrEquals: [
                  '@triggerBody()?[\'quantity\']'
                  5
                ]
              }
            ]
          }
          type: 'If'
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

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}


// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource backendPlaceOrderAPI 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'orderworflow-backend'
  parent: apim
  properties: {
    description: 'Backend for the Place Order API'
    url: '${placeOrderWorkflow.listCallbackUrl().basePath}/triggers'
    protocol: 'http'
    credentials: {
      query: {
          sig: [ placeOrderWorkflow.listCallbackUrl().queries.sig ]
          'api-version': [ placeOrderWorkflow.listCallbackUrl().queries['api-version'] ]
          sp: [ placeOrderWorkflow.listCallbackUrl().queries.sp ]
          sv: [ placeOrderWorkflow.listCallbackUrl().queries.sv ]        
      }
    }    
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: apiName
  properties: {
    apiType: 'http'
    displayName: apiDisplayName
    description: apiDescription
    apiRevision: '1'
    subscriptionRequired: false
    path: apiPath
    contact: {
      email: apiContactEmail
      name: apiContactName
      url: apiContactUrl
    }    
    protocols: [
      'https'
    ]
    authenticationSettings: {
      oAuth2AuthenticationSettings: []
      openidAuthenticationSettings: []
    }
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'subscription-key'
    }
    isCurrent: true
    format: 'openapi+json'
    value: loadTextContent('openapi.json')
  }
}

resource APIPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    value: loadTextContent('policy.xml')
    format: 'rawxml'
  }
}

resource apiCenterService 'Microsoft.ApiCenter/services@2024-06-01-preview' existing = {
  name: apicServiceName
}

resource apiCenterWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-06-01-preview' existing = {
  parent: apiCenterService
  name: 'default'
}

// Add API resources using a loop
resource apiCenterAPI 'Microsoft.ApiCenter/services/workspaces/apis@2024-06-01-preview' = {
  parent: apiCenterWorkspace
  name: apiName
  properties: {
    title: apiDisplayName
    kind: 'rest'
    lifecycleState: apiLifecycleStage
    externalDocumentation: [
      {
        description: apiDescription
        title: apiDisplayName
        url: apiContactUrl
      }
    ]
    contacts: [
      {
        name: apiContactName
        email: apiContactEmail
        url: apiContactUrl
      }
    ]
    customProperties: {}
    summary: apiDescription
    description: apiDescription
  }
}

// Add API Version resources using a loop
resource apiVersion 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-06-01-preview' = {
  parent: apiCenterAPI
  name: apiVersionName
  properties: {
    title: apiVersionDisplayName
    lifecycleStage: apiLifecycleStage
  }
}

// Add API Definition resource
resource apiDefinition 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-06-01-preview' = {
  parent: apiVersion
  name: apiDefinitionName
  properties: {
    description: apiDefinitionDescription
    title: apiDefinitionDisplayName
  }
}

// Add API Deployment resource
resource apiDeployment 'Microsoft.ApiCenter/services/workspaces/apis/deployments@2024-06-01-preview' = {
  parent: apiCenterAPI
  name: apiDeploymentName
  properties: {
    description: apiDeploymentDescription
    title: apiDeploymentDisplayName
    environmentId: '/workspaces/default/environments/${environmentName}'
    definitionId: '/workspaces/${apiCenterWorkspace.name}/apis/${apiCenterAPI.name}/versions/${apiVersion.name}/definitions/${apiDefinition.name}'
    state: 'active'
    server: {
      runtimeUri: [
        '${apim.properties.gatewayUrl}/${apiPath}'
      ]
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

output name string = api.name
output endpoint string = '${apim.properties.gatewayUrl}/${apiPath}'
