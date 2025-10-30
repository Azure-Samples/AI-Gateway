# MCP-PRM-OAuth Infrastructure - Summary

## Overview
This document describes the architecture of the Bicep codebases for the MCP (Model Context Protocol) with PRM (Protected Resource Metadata) OAuth implementation.

## What Was Implemented

- **Resources:**
  - Azure Container Registry (ACR)
  - Container App Environment
  - User-Assigned Managed Identity (inline resource)
  - Container App for MCP Server
  - Log Analytics Workspace
  - Application Insights
  - API Management (APIM)
  - Managed Identity module
  - Entra ID App Registration with Microsoft Graph extension
  - APIM configuration for MCP PRM endpoints with OAuth policies

## Architectural Descision

### Resources Deployed (in order):
1. **Log Analytics Workspace** - Centralised logging
2. **Application Insights** - Application monitoring
3. **API Management (APIM)** - API gateway with OAuth policies
4. **User-Assigned Managed Identity** - Shared identity for Container App and Web App
5. **Container Registry (ACR)** - Docker image storage
6. **Container App Environment** - Hosting environment for containers
7. **ACR Pull Role Assignment** - Grants managed identity ACR pull permissions
8. **MCP Server Container App** - Containerized MCP server instance
9. **Entra ID App Registration** (conditional) - OAuth application for MCP
10. **MCP API Configuration** - APIM policies for OAuth validation and PRM endpoint

### Key Integration Points:
- **Managed Identity**: Created once via module, used by Container App
- **Entra App**: Configured with federated credentials trusting the managed identity
- **APIM**: Hosts MCP API with OAuth token validation and PRM metadata endpoint
- **Container App**: Hosts the MCP server with managed identity authentication

## Known Issues & Workarounds

### 1. Unused Parameters
Several parameters are declared but not used in the current implementation:
- `aiServicesConfig`
- `modelsConfig`
- `inferenceAPIType`
- `inferenceAPIPath`
- `foundryProjectName`
- `entraIDClientId`, `entraIDClientSecret`, `oauthScopes`
- `encryptionIV`, `encryptionKey`

**Reason:** These are retained for compatibility with `params.json` and potential future features deployments.

## Architecture Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                         Azure Resource Group                   │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────┐      ┌─────────────────────────────────┐ │
│  │ Log Analytics    │◄─────│  Application Insights           │ │
│  │ Workspace        │      │  (Monitoring & Metrics)         │ │
│  └──────────────────┘      └─────────────────────────────────┘ │
│           ▲                                                    │
│           │                                                    │
│  ┌────────┴────────────────────────────────────────────────┐   │
│  │          API Management (APIM)                          │   │
│  │   ┌──────────────────┐   ┌───────────────────────────┐  │   │
│  │   │ MCP API          │   │ PRM Endpoint              │  │   │
│  │   │ /mcp (OAuth)     │   │ /.well-known/oauth-...    │  │   │
│  │   │- Token Validation│   │ - Anonymous Access        │  │   │
│  │   └──────────────────┘   └───────────────────────────┘  │   │
│  └───────────────────┬─────────────────────────────────────┘   │
│                      │                                         │
│                      ▼                                         │
│         ┌──────────────────────────┐                           │
│         │  Container App           │                           │
│         │  (MCP Server)            │                           │
│         │  - Docker Container      │                           │
│         │  - Managed Identity      │                           │
│         └───────┬──────────────────┘                           │
│                 │                                              │
│                 └─┐                                            │
│                   ▼                                            │
│         ┌────────────────────┐                                 │
│         │ Managed Identity   │                                 │
│         │ (User-Assigned)    │                                 │
│         └────────┬───────────┘                                 │
│                  │                                             │
│                  │ Federated Credential                        │
│                  ▼                                             │
│         ┌────────────────────┐                                 │
│         │ Entra ID App       │                                 │
│         │ - OAuth Client     │                                 │
│         │ - user_impersonate │                                 │
│         └────────────────────┘                                 │
│                                                                │
│  ┌──────────────────┐         ┌─────────────────────────────┐  │
│  │ Container        │         │ Container App Environment   │  │
│  │ Registry (ACR)   │         │ (Managed Environment)       │  │
│  └──────────────────┘         └─────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

## MCP PRM API Flow

```
┌──────────────┐
│ MCP Client   │
└──────┬───────┘
       │
       │ 1. GET /mcp/.well-known/oauth-protected-resource
       ├────────────────────────────────────►┌────────────────┐
       │                                     │ APIM Gateway   │
       │ 2. Returns PRM metadata             │ (Anonymous)    │
       │◄────────────────────────────────────┤                │
       │   {resource, authorization_servers} └────────────────┘
       │
       │ 3. Acquires OAuth token from Entra ID
       ├──────────────────────────────────────►┌────────────────┐
       │                                       │ Entra ID       │
       │ 4. Returns access token               │                │
       │◄──────────────────────────────────────┤                │
       │                                       └────────────────┘
       │
       │ 5. POST /mcp with Bearer token
       ├─────────────────────────────────────►┌─────────────────┐
       │                                      │ APIM Gateway    │
       │                                      │ - Validates JWT │
       │                                      │ - Checks aud    │
       │                                      └────────┬────────┘
       │                                               │
       │                                      ┌────────▼────────┐
       │ 6. MCP response                      │ Web App         │
       │◄─────────────────────────────────────│ (MCP Server)    │
       │                                      └─────────────────┘
       │
```

- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [RFC 9728 - Protected Resource Metadata](https://www.rfc-editor.org/rfc/rfc9728.html)
- [Azure API Management OAuth Policies](https://learn.microsoft.com/azure/api-management/api-management-authentication-policies)
- [Microsoft Graph Bicep Extension](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-extensibility-graph)

---

