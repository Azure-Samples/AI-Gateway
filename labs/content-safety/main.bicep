// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string
param apimSubscriptionsConfig array = []
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

// 1. API Management
module apimModule '../../modules/apim/v2/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
  }
}

// 2. AI Foundry
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
    name: 'foundryModule'
    params: {
      aiServicesConfig: aiServicesConfig
      modelsConfig: modelsConfig
      apimPrincipalId: apimModule.outputs.principalId
      foundryProjectName: foundryProjectName
    }
  }

// 3. APIM Inference API
module inferenceAPIModule '../../modules/apim/v2/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    aiServicesConfig: foundryModule.outputs.extendedAIServicesConfig
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
    configureCircuitBreaker: true
  }
}

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: 'apim-${resourceSuffix}'
  dependsOn: [
    inferenceAPIModule
  ]
}

// 4. Content Safety
resource contentSafetyResource 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: 'contentsafety-${resourceSuffix}'
  location: resourceGroup().location
  sku: {
    name: 'S0'
  }
  kind: 'ContentSafety'
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: toLower('contentsafety-${resourceSuffix}')
  }
}

resource raiBlocklist 'Microsoft.CognitiveServices/accounts/raiBlocklists@2025-06-01' = {
  parent: contentSafetyResource
  name: 'blocklist1' // this name is hard coded in the policy.xml file
  properties: {
    description: 'Forbidden inputs blocklist'
  }  
}

/*
// the following blocklist items fail to deploy with error: [{"code":"IfMatchPreconditionFailed","message":"The specified precondition 'If-Match = \"\"d00087d4-0000-0200-0000-687798f10000\"\"' failed."},{"code":"IfMatchPreconditionFailed","message":"The specified precondition 'If-Match = \"\"d00087d4-0000-0200-0000-687798f10000\"\"' failed."}]}}
resource raiBlocklistItemName 'Microsoft.CognitiveServices/accounts/raiBlocklists/raiBlocklistItems@2025-06-01' = {
  parent: raiBlocklist
  name: 'name'
  properties: {
    isRegex: false
    pattern: 'Alex'
  }
}

resource raiBlocklistItemSSN 'Microsoft.CognitiveServices/accounts/raiBlocklists/raiBlocklistItems@2025-06-01' = {
  parent: raiBlocklist
  name: 'ssn'
  properties: {
    isRegex: true
    pattern: '^\\d{3}-?\\d{2}-?\\d{4}$'
  }
}

resource raiBlocklistItemCreditCard 'Microsoft.CognitiveServices/accounts/raiBlocklists/raiBlocklistItems@2025-06-01' = {
  parent: raiBlocklist
  name: 'creditcard'
  properties: {
    isRegex: true
    pattern: '^(?:4[0-9]{12}(?:[0-9]{3})?|[25][1-7][0-9]{14}|6(?:011|5[0-9][0-9])[0-9]{12}|3[47][0-9]{13}|3(?:0[0-5]|[68][0-9])[0-9]{11}|(?:2131|1800|35\\d{3})\\d{11})$'
  }
}
*/

var cognitiveServicesReaderDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
resource contentSafetyRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: contentSafetyResource
  name: guid(subscription().id, resourceGroup().id, contentSafetyResource.name, cognitiveServicesReaderDefinitionID)
  properties: {
      roleDefinitionId: cognitiveServicesReaderDefinitionID
      principalId: apim.identity.principalId
      principalType: 'ServicePrincipal'
  }
}

resource contentSafetyRoleAssignmentToDeployer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: contentSafetyResource
  name: guid(subscription().id, resourceGroup().id, contentSafetyResource.name, cognitiveServicesReaderDefinitionID, deployer().objectId)
  properties: {
      roleDefinitionId: cognitiveServicesReaderDefinitionID
      principalId: deployer().objectId
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service/backends
resource contentSafetyBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'content-safety-backend' // this name is hard coded in the policy.xml file
  parent: apim
  properties: {
    description: 'Content Safety Backend'
    url: contentSafetyResource.properties.endpoint
    protocol: 'http'
    credentials: {
      #disable-next-line BCP037
      managedIdentity: {
          resource: 'https://cognitiveservices.azure.com'
      }
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

output apimServiceId string = apimModule.outputs.id
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl

output apimSubscriptions array = apimModule.outputs.apimSubscriptions



