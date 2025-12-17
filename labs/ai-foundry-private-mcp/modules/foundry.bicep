param location string
param aiFoundryName string
param aiFoundryProjectName string
param modelsConfig array
param logAnalyticsName string

// Create a Foundry Account 
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: aiFoundryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    // Networking
    publicNetworkAccess: 'Disabled'

    // Specifies whether this resource support project management as child resources, used as containers for access management, data isolation, and cost in AI Foundry.
    allowProjectManagement: true

    // Defines developer API endpoint subdomain
    customSubDomainName: aiFoundryName

    // Auth
    disableLocalAuth: false
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  name: aiFoundryProjectName
  parent: account
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
  dependsOn: [
    account
  ]
}

resource modelDeployments 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = [for model in modelsConfig: {
  name: model.name
  parent: account
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
  dependsOn: [
    project
  ]
}]


// https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' =  {
    name: '${account.name}-diagnostics'
    scope: account
    properties: {
      workspaceId: logAnalytics.id
      logs: []
      metrics: [
        {
          category: 'AllMetrics'
          enabled: true
        }
      ]
    }
}


resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsName
  location: location
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}



output aiFoundryId string = account.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output aiFoundryProjectEndpoint string = 'https://${account.name}.services.ai.azure.com/api/projects/${project.name}'
