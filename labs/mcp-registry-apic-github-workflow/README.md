---
name: MCP Registry with API Center (CI/CD)
architectureDiagram: images/apic-registry.gif
categories:
  - Knowledge & Tools
  - Platform Capabilities
services:
  - Azure API Center
  - MCP
  - GitHub Actions
shortDescription: Automated MCP server registry with Azure API Center using GitOps and GitHub CI/CD pipelines.
detailedDescription: Demonstrates a fully automated Model Context Protocol server registry integrating with Azure API Center using GitHub CI/CD pipelines. Developers add MCP servers by committing JSON files, GitHub Actions automatically validate and deploy changes, and Azure API Center becomes the centralized registry for organizational MCP server discovery. Complete GitOps solution with infrastructure as code using Bicep.
tags: []
authors:
  - frankqianms
---

# MCP Registry to Azure API Center using CI/CD pipelines


This project demonstrates how to establish a **fully automated Model Context Protocol (MCP) server registry** that seamlessly integrates with **Azure API Center using GitHub CI/CD pipelines**. The key benefit of this lab is enabling organizations to automatically discover, register, and manage MCP servers through a GitOps workflow.

## Overview

This lab showcases a complete **GitOps solution** where:
- **Developers** add MCP servers by committing JSON configuration files
- **GitHub Actions** automatically validate and deploy changes  
- **Azure API Center** becomes the centralized registry for organizational MCP server discovery
- **Teams** can easily find and integrate available MCP servers across the enterprise

The solution registers MCP servers defined in individual directories under `src/remote-mcp-servers/` into an Azure API Center instance through intelligent CI/CD automation.

## Architecture

This lab demonstrates a modern **GitOps architecture** for MCP server lifecycle management:

- **GitHub Repository**: Source of truth for MCP server definitions and infrastructure
- **GitHub Actions CI/CD**: Automated validation, testing, and deployment pipeline  
- **Azure API Center**: Enterprise-grade registry for MCP server discovery and governance
- **Bicep Templates**: Infrastructure as Code for consistent, repeatable deployments
- **Organized Server Structure**: Each MCP server has its own directory with configuration and metadata files

### CI/CD Automation Flow

```mermaid
graph LR
    A[Developer adds MCP server] --> B[Git commit & push]
    B --> C[GitHub Actions triggered]
    C --> D[Validate JSON configs]
    D --> E[Deploy to Azure API Center]
    E --> F[MCP server available for discovery]
```

## Project Structure

```
├── infra/
│   ├── single-mcp.bicep             # Template for individual MCP server deployment
│   └── single-mcp.parameters.json   # Parameters for individual server deployment
├── src/
│   └── remote-mcp-servers/          # Individual MCP server definitions
│       ├── github-mcp-server/
│       │   ├── github-mcp-server.json         # Server configuration
│       │   └── github-mcp-server-metadata.json # Server metadata
│       ├── msdocs-mcp-server/
│       │   ├── msdocs-mcp-server.json
│       │   └── msdocs-mcp-server-metadata.json
│       └── neon-mcp-server/
│           ├── neon-mcp-server.json
│           └── neon-mcp-server-metadata.json
├── azure.yaml                       # Azure Developer CLI config
└── README.md                        # This file
```

## Deployment Strategy

The current project supports individual MCP server deployment using the `single-mcp.bicep` template. This approach allows for:

- **Focused Deployment**: Deploy only specific MCP servers that need updates
- **Template Reusability**: Single Bicep template handles any MCP server configuration
- **Parameter-driven**: Server-specific details passed as parameters during deployment
- **Organized Structure**: Each server has its own directory with configuration and metadata

## Prerequisites

### Azure Setup

1. **Azure Subscription**: Active Azure subscription with appropriate permissions to create and manage API Center resources
3. **Azure API Center**: An existing API Center instance (or permissions to create one)

### GitHub Setup

1. **Repository Variables**: Configure in your GitHub repository settings
   - `AZURE_CLIENT_ID`: Service Principal Application ID
   - `AZURE_TENANT_ID`: Azure Active Directory Tenant ID
   - `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID
   - `MCP_REGISTRY_RG_NAME`: Resource group name where the APIC service is.
   - `MCP_REGISTRY_APIC_NAME`: The name of your existing APIC service.
   - `MCP_REGISTRY_APIC_LOCATION`: The location of your APIC service.

  > If the resource group and the APIC service don't exist, a new one will be ceated with provided `MCP_REGISTRY_RG_NAME`, `MCP_REGISTRY_APIC_NAME` and `MCP_REGISTRY_APIC_LOCATION`. 

## MCP Server Configuration

Each MCP server is defined in its own directory under `src/remote-mcp-servers/` with two required files:

### Server Configuration File (`{server-name}.json`)

```json
{
  "id": "github-mcp-server",
  "name": "GitHub",
  "description": "Access GitHub repositories, issues, and pull requests through secure API integration.",
  "version": "1.0.0",
  "remotes": [
    {
      "transport_type": "sse",
      "url": "https://api.githubcopilot.com/mcp"
    }
  ]
}
```

### Server Metadata File (`{server-name}-metadata.json`)

```json
{
  "x-ms-icon": "https://avatars.githubusercontent.com/github?s=64",
  "x-ms-partner": true,
  "repository": {
    "url": "https://github.com/github/github-mcp-server",
    "source": "partner",
    "id": ""
  },
  "tags": ["git", "github", "repositories", "issues", "pull-requests"],
  "category": "Development",
  "publisher": "GitHub",
  "license": "MIT"
}
```

### Required Fields

#### Configuration File:
- `id`: Unique identifier for the MCP server
- `name`: Display name for the server
- `description`: Human-readable description of the server's capabilities
- `version`: Version of the MCP server
- `remotes`: Array of remote connection configurations with `transport_type` and `url`

#### Metadata File:
- `x-ms-icon`(optional): URL to the server icon
- `repository`(optional): Repository information including URL and source
- `tags`(optional): Array of descriptive tags for categorization
- `category`(optional): Primary category classification
- `publisher`(optional): Name of the server publisher
- `documentations`(optional): External documentation information

## Deployment



### Development Workflow

```powershell
# Clone repository
git clone https://github.com/your-org/mcp-registry-apic
cd mcp-registry-apic

# Create feature branch
git checkout -b feature/add-new-mcp

# Create new server directory
mkdir "src\remote-mcp-servers\my-new-server"

# Create configuration files
# - my-new-server.json (server configuration)
# - my-new-server-metadata.json (server metadata)

# Validate JSON syntax
Get-Content "src\remote-mcp-servers\my-new-server\my-new-server.json" | ConvertFrom-Json
Get-Content "src\remote-mcp-servers\my-new-server\my-new-server-metadata.json" | ConvertFrom-Json

# Test deployment locally (optional)
az deployment group validate `
  --resource-group test-rg `
  --template-file infra/single-mcp.bicep `
  --parameters infra/single-mcp.parameters.json

# Commit and push
git add .
git commit -m "Add new MCP server: my-new-server"
git push origin feature/add-new-mcp
```

### File Structure for New Servers

Each new MCP server should follow this structure:
```
src/remote-mcp-servers/
└── your-server-name/
    ├── your-server-name.json         # Required: Server configuration
    └── your-server-name-metadata.json # Required: Server metadata
```

## License

This project is licensed under the MIT License. See LICENSE file for details.
