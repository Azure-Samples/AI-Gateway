// Creates a Shared Private Link from the Azure AI Search service to the AI Services
// account (groupId: openai_account), and auto-approves the resulting pending
// private endpoint connection on the AI Services side.
//
// Why: First-class indexer skills (e.g., AzureOpenAIEmbeddingSkill) automatically
// route through this SPL when the resourceUri matches. This provides defense in
// depth alongside `publicNetworkAccess: Enabled` + `bypass: AzureServices` on the
// AI Services account (which is what the Custom Web API ChatCompletionSkill relies
// on, since custom Web API skills do NOT auto-route through SPL).
//
// Note: This module assumes the Search service and AI Services account are deployed
// in the same resource group as this deployment.

@description('Name of the Azure AI Search service that will own the SPL')
param searchServiceName string

@description('Name of the AI Services account being privately linked')
param aiServicesAccountName string

@description('Name of the SPL resource on the Search service')
param sharedPrivateLinkName string = 'search-to-aiservices-openai'

@description('Group id for the shared private link target. For AI Services accounts (kind=AIServices) used as Azure OpenAI, use openai_account.')
param groupId string = 'openai_account'

@description('Location for the auto-approval deployment script')
param location string = resourceGroup().location

@description('Force a re-run of the approval script (bump to retry approval)')
param approvalScriptForceUpdateTag string = utcNow()

resource searchService 'Microsoft.Search/searchServices@2025-05-01' existing = {
  name: searchServiceName
}

resource aiServicesAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: aiServicesAccountName
}

// Create the shared private link request on the Search service. Initial status is Pending.
resource sharedPrivateLink 'Microsoft.Search/searchServices/sharedPrivateLinkResources@2025-05-01' = {
  parent: searchService
  name: sharedPrivateLinkName
  properties: {
    privateLinkResourceId: aiServicesAccount.id
    groupId: groupId
    requestMessage: 'Azure AI Search indexer skill access to AI Services (auto-approved by Bicep)'
  }
}

// Managed identity used by the deployment script to approve the pending PE connection.
resource approvalIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${searchServiceName}-${sharedPrivateLinkName}-approver'
  location: location
}

// Cognitive Services Contributor role: lets the script approve PE connections on the account.
// Role definition id: 25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68
resource cognitiveServicesContributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'
  scope: subscription()
}

resource approvalRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiServicesAccount
  name: guid(approvalIdentity.id, cognitiveServicesContributor.id, aiServicesAccount.id)
  properties: {
    principalId: approvalIdentity.properties.principalId
    roleDefinitionId: cognitiveServicesContributor.id
    principalType: 'ServicePrincipal'
  }
}

// Polls the AI Services account for a Pending PE connection that came from this SPL,
// then approves it. Idempotent: silently succeeds if already Approved.
resource approveScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${searchServiceName}-${sharedPrivateLinkName}-approve'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${approvalIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.59.0'
    timeout: 'PT15M'
    retentionInterval: 'PT1H'
    forceUpdateTag: approvalScriptForceUpdateTag
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      { name: 'ACCOUNT_ID', value: aiServicesAccount.id }
      { name: 'SPL_NAME', value: sharedPrivateLinkName }
    ]
    scriptContent: '''
      set -e
      echo "Looking for PE connection on $ACCOUNT_ID matching SPL '$SPL_NAME'..."
      for i in $(seq 1 30); do
        # PE connection name pattern from Search SPL: "<spl-name>.<guid>"
        PE_NAME=$(az rest --method get \
          --uri "https://management.azure.com${ACCOUNT_ID}/privateEndpointConnections?api-version=2024-10-01" \
          --query "value[?starts_with(name, '${SPL_NAME}.')] | [0].name" -o tsv 2>/dev/null || true)
        if [ -n "$PE_NAME" ] && [ "$PE_NAME" != "None" ]; then
          # name comes back as "<account>/<conn>"; strip parent prefix if present
          SHORT_NAME="${PE_NAME##*/}"
          STATUS=$(az rest --method get \
            --uri "https://management.azure.com${ACCOUNT_ID}/privateEndpointConnections/${SHORT_NAME}?api-version=2024-10-01" \
            --query "properties.privateLinkServiceConnectionState.status" -o tsv)
          echo "Found PE connection '$SHORT_NAME' with status '$STATUS'"
          if [ "$STATUS" = "Approved" ]; then
            echo "Already approved."
            exit 0
          fi
          BODY=$(cat <<EOF
{"properties":{"privateLinkServiceConnectionState":{"status":"Approved","description":"Auto-approved by Bicep deployment for Search SPL","actionsRequired":"None"}}}
EOF
)
          az rest --method put \
            --uri "https://management.azure.com${ACCOUNT_ID}/privateEndpointConnections/${SHORT_NAME}?api-version=2024-10-01" \
            --body "$BODY"
          echo "Approval submitted."
          exit 0
        fi
        echo "Attempt $i: PE connection not yet visible, sleeping 20s..."
        sleep 20
      done
      echo "ERROR: PE connection for SPL '$SPL_NAME' did not appear within timeout." >&2
      exit 1
    '''
  }
  dependsOn: [
    sharedPrivateLink
    approvalRoleAssignment
  ]
}

output sharedPrivateLinkResourceId string = sharedPrivateLink.id
output sharedPrivateLinkStatus string = sharedPrivateLink.properties.status
