// Auto-approve the AI Search → AI Services shared private link from inside the deployment.
// Uses a Microsoft.Resources/deploymentScripts (ACI) with bring-your-own-storage and
// identity-based auth to bypass tenants that block shared-key storage access.

@description('Azure region for the deployment')
param location string

@description('AI Services account name that owns the pending PE connection')
param aiServicesAccountName string

@description('Shared private link name (the PE connection name on the account starts with this prefix)')
param sharedPrivateLinkName string

@description('Resource name suffix for the UAMI / storage account / script (must be globally unique for storage)')
param nameSuffix string = uniqueString(resourceGroup().id, sharedPrivateLinkName)

@description('Force a re-run by changing this value (e.g., a new utcNow() default at template root)')
param forceUpdateTag string = utcNow()

var roleStorageBlobDataOwner = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var roleStorageFileDataPrivilegedContributor = '69566ab7-960f-475b-8e7c-b3118f30c6bd'
var roleCognitiveServicesContributor = '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiServicesAccountName
}

// Microsoft.Resources/deploymentScripts only supports user-assigned managed identities
// (system-assigned is not allowed because the identity must exist before the ACI container starts).
// See https://learn.microsoft.com/azure/azure-resource-manager/deployment-scripts/script-identity
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'spl-approver-${nameSuffix}'
  location: location
}

var storageAccountName = 'splds${nameSuffix}'

resource byoStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: take(toLower(storageAccountName), 24)
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // deploymentScripts ACI requires shared-key access on its backing storage account.
    // Tenants that enforce 'KeyBasedAuthenticationNotPermitted' must keep
    // autoApproveSharedPrivateLink = false and use the notebook fallback.
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource byoFile 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: byoStorage
  name: 'default'
}

resource raStorageBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: byoStorage
  name: guid(byoStorage.id, uami.id, roleStorageBlobDataOwner)
  properties: {
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataOwner)
  }
}

resource raStorageFile 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: byoStorage
  name: guid(byoStorage.id, uami.id, roleStorageFileDataPrivilegedContributor)
  properties: {
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageFileDataPrivilegedContributor)
  }
}

resource raAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiServices
  name: guid(aiServices.id, uami.id, roleCognitiveServicesContributor)
  properties: {
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleCognitiveServicesContributor)
  }
}

resource approveScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'approve-spl-${nameSuffix}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.62.0'
    timeout: 'PT30M'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: forceUpdateTag
    storageAccountSettings: {
      storageAccountName: byoStorage.name
    }
    environmentVariables: [
      {
        name: 'AI_ACCOUNT_ID'
        value: aiServices.id
      }
      {
        name: 'SPL_NAME'
        value: sharedPrivateLinkName
      }
    ]
    scriptContent: '''
set -e
echo "Looking for pending PE connection on $AI_ACCOUNT_ID matching $SPL_NAME.*"
for i in $(seq 1 30); do
  PEC_NAME=$(az network private-endpoint-connection list --id "$AI_ACCOUNT_ID" --query "[?starts_with(name, '${SPL_NAME}.')].name | [0]" -o tsv || true)
  if [ -n "$PEC_NAME" ] && [ "$PEC_NAME" != "None" ]; then
    echo "Found PE connection: $PEC_NAME"
    STATUS=$(az network private-endpoint-connection show --id "$AI_ACCOUNT_ID/privateEndpointConnections/$PEC_NAME" --query "properties.privateLinkServiceConnectionState.status" -o tsv)
    echo "Current status: $STATUS"
    if [ "$STATUS" = "Approved" ]; then
      echo "Already Approved."
      break
    fi
    az network private-endpoint-connection approve --id "$AI_ACCOUNT_ID/privateEndpointConnections/$PEC_NAME" --description "Auto-approved by spl-auto-approve module" -o none
    echo "Approved."
    break
  fi
  echo "Not visible yet, sleeping 20s..."
  sleep 20
done
if [ -z "$PEC_NAME" ] || [ "$PEC_NAME" = "None" ]; then
  echo "ERROR: did not find pending PE connection within timeout"
  exit 1
fi
'''
  }
  dependsOn: [
    raStorageBlob
    raStorageFile
    raAccount
    byoFile
  ]
}

output approvedConnectionLogUri string = approveScript.properties.outputs == null ? '' : ''
