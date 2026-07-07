extension microsoftGraphV1

@description('The name of the MCP Entra application')
param mcpAppUniqueName string

@description('The display name of the MCP Entra application')
param mcpAppDisplayName string

@description('Tenant ID where the application is registered')
param tenantId string = tenant().tenantId

@description('The principle id of the user-assigned managed identity')
param userAssignedIdentityPrincipleId string

@description('The container app name for callback URL configuration')
param webAppName string

@description('The Application ID URI to expose (must match the PRM resource and the JWT audience). Example: https://<apim>.azure-api.net/mcp')
param applicationIdUri string

var loginEndpoint = environment().authentication.loginEndpoint
var issuer = '${loginEndpoint}${tenantId}/v2.0'

// Get reference to the Container App
resource containerApp 'Microsoft.App/containerApps@2023-11-02-preview' existing = {
  name: webAppName
}

resource mcpEntraApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: mcpAppDisplayName
  uniqueName: mcpAppUniqueName
  // Application ID URI. Aligns with the PRM 'resource' and the validate-jwt audience.
  identifierUris: [
    applicationIdUri
  ]
  api: {
    oauth2PermissionScopes: [
      {
        id: guid(mcpAppUniqueName, 'user_impersonate')
        adminConsentDescription: 'Allows the application to access MCP resources on behalf of the signed-in user'
        adminConsentDisplayName: 'Access MCP resources'
        isEnabled: true
        type: 'User'
        userConsentDescription: 'Allows the app to access MCP resources on your behalf'
        userConsentDisplayName: 'Access MCP resources'
        value: 'user_impersonate'
      }
    ]
    requestedAccessTokenVersion: 2
    preAuthorizedApplications: [
      {
        appId: 'aebc6443-996d-45c2-90f0-388ff96faa56'
        delegatedPermissionIds: [
          guid(mcpAppUniqueName, 'user_impersonate')
        ]
      }
    ]
  }
  requiredResourceAccess: [
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
      resourceAccess: [
        {
          id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
          type: 'Scope'
        }
      ]
    }
  ]
  spa: {
    redirectUris: [
      'https://${containerApp.properties.configuration.ingress.fqdn}/auth/callback'
    ]
  }
  // Public client (Authorization Code + PKCE, no client secret) for MCP Inspector.
  // Registering these as public-client (not SPA) redirect URIs avoids AADSTS9002327.
  publicClient: {
    redirectUris: [
      'http://localhost:6274/oauth/callback'
      'http://localhost:6274/oauth/callback/debug'
    ]
  }

  resource fic 'federatedIdentityCredentials@v1.0' = {
    name: '${mcpEntraApp.uniqueName}/msiAsFic'
    description: 'Trust the user-assigned MI as a credential for the MCP app'
    audiences: [
       'api://AzureADTokenExchange'
    ]
    issuer: issuer
    subject: userAssignedIdentityPrincipleId
  }
}

resource applicationRegistrationServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: mcpEntraApp.appId
}

// Outputs
output mcpAppId string = mcpEntraApp.appId
output mcpAppTenantId string = tenantId
