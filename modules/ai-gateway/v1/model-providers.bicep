param foundryAccountName string = ''
param apimName string
param workspaceName string
param modelProviderName string
param modelsConfig array = []

resource apimService 'Microsoft.ApiManagement/service@2025-09-01-preview' existing = {
  name: apimName
}

resource workspace 'Microsoft.ApiManagement/service/workspaces@2025-09-01-preview' existing = {
  parent: apimService
  name: workspaceName
}

resource modelProvider 'Microsoft.ApiManagement/service/workspaces/modelProviders@2025-09-01-preview' existing = {
  parent: workspace
  name: modelProviderName
}

resource models 'Microsoft.ApiManagement/service/workspaces/modelProviders/models@2025-09-01-preview' = [for model in modelsConfig: {
  parent: modelProvider
  name: length(foundryAccountName) > 0 ? '${foundryAccountName}-${model.name}' : model.name
  properties: {
    description: model.?description ?? null
    displayName: length(foundryAccountName) > 0 ? '${foundryAccountName}-${model.name}' : model.name
    apiFormat: model.modelFormat
    supportedEndpoints: model.supportedEndpoints
    deployment: {
      resourceId: model.resourceId
      modelName: model.modelName
      modelVersion: model.?modelVersion ?? null
    }
    policies: model.?policies ?? []
  }
}]
