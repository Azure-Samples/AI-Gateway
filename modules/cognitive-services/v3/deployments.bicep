

@description('Configuration array for the model deployments')
param modelsConfig array = []

param cognitiveServiceName string

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: cognitiveServiceName
}

@batchSize(1)
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = [for (model, i) in modelsConfig: if(contains(cognitiveService.name, modelsConfig[i].?aiservice != null ? modelsConfig[i].aiservice : '' )) {
  name: model.name
  parent: cognitiveService
  sku: {
    name: model.sku
    capacity: model.capacity
  }
  properties: {
    model: {
      format: model.?publisher ?? model.?format
      name: model.name
      version: model.version
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}]

output modelDeployments array = [for (model, i) in modelsConfig: {
  name: modelDeployment[i].name
  resourceId: modelDeployment[i].id
  modelName: modelDeployment[i].properties.model.name
  modelVersion: modelDeployment[i].properties.model.version
  modelFormat: modelDeployment[i].properties.model.format
  description: modelsConfig[i].?description ?? null
  supportedEndpoints: concat(
    (modelDeployment[i].properties.?capabilities.?chatCompletion ?? 'false') == 'true' ? ['/openai/v1/chat/completions'] : [],
    (modelDeployment[i].properties.?capabilities.?responses ?? 'false') == 'true' ? ['/openai/v1/responses'] : []
  )
  policies: modelsConfig[i].?policies ?? []
}]
