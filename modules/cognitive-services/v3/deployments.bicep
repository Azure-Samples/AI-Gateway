

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
      format: model.publisher
      name: model.name
      version: model.version
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}]
