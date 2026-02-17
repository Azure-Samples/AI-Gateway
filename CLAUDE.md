# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Azure AI Gateway experimental labs and samples, demonstrating API Management patterns for AI services. The project is organized as a collection of Jupyter notebook-based labs that explore different aspects of the AI Gateway pattern using Azure API Management with Azure OpenAI and other AI services.

## Development Environment Setup

### Python Environment
```bash
# Install Python dependencies
pip install -r requirements.txt

# The comprehensive requirements.txt covers all labs
# Key packages include: openai, azure-identity, azure-mgmt-apimanagement, 
# azure-ai-projects, mcp, autogen-core, semantic-kernel
```

### Workshop Documentation (Docusaurus)
```bash
# Navigate to workshop directory
cd workshop

# Install dependencies and run development server
npm install
npm start

# Build static site
npm run build

# Type checking
npm run typecheck
```

## Repository Structure

- **`labs/`** - Individual experimental labs as Jupyter notebooks
  - Each lab contains: README.md, notebook files (.ipynb), Bicep templates, policy XML files
  - Lab categories: AI Agents, Inference API, Azure OpenAI-based
  - Notable labs: model-context-protocol, openai-agents, semantic-caching, backend-pool-load-balancing

- **`modules/`** - Reusable Bicep modules for Azure resources
  - `apim/` - Azure API Management modules (v1, v2)
  - `cognitive-services/` - Azure OpenAI and AI Foundry modules  
  - `monitor/` - Application Insights modules
  - `network/` - Virtual network modules

- **`shared/`** - Shared Python utilities
  - `utils.py` - Core utilities for Azure resource management, deployment, cleanup
  - `apimtools.py` - APIM-specific client tools and API discovery
  - `snippets/` - Reusable code snippets for common operations

- **`tools/`** - Supporting tools and utilities
  - Mock server implementation
  - Tracing and streaming tools
  - Rate limiting and testing utilities

- **`workshop/`** - Docusaurus-based documentation website

## Common Development Commands

### Python Environment Setup
```bash
# Install dependencies for all labs
pip install -r requirements.txt

# Run individual Jupyter notebooks (preferred method for lab development)
jupyter lab labs/<lab-name>/<notebook-name>.ipynb
```

### Azure Resource Management
```bash
# Deploy lab infrastructure (run from lab directory)
az deployment group create --resource-group <rg-name> --template-file main.bicep

# Clean up resources (use dedicated cleanup notebooks)
jupyter lab clean-up-resources.ipynb
```

### Workshop Documentation (Docusaurus)
```bash
cd workshop

# Development
npm install
npm start  # Development server on localhost:3000

# Build and type checking
npm run build
npm run typecheck
```

## Key Architecture Patterns

### Lab Structure
Each lab follows a consistent pattern:
- `main.bicep` - Infrastructure as Code template
- `policy.xml` - APIM policy configuration
- `<lab-name>.ipynb` - Main implementation notebook
- `clean-up-resources.ipynb` - Resource cleanup
- `README.md` - Lab-specific documentation

### Azure Resource Organization
- Resource groups follow naming: `lab-<deployment-name>`
- Resources use unique suffixes via `uniqueString()` function
- Cleanup includes purging soft-deleted resources (APIM, Cognitive Services, Key Vault)

### APIM Integration Patterns
- Backend pool load balancing for resilience
- Token-based rate limiting and metrics
- Semantic caching for performance
- Policy-based content filtering and safety
- OAuth 2.0 and client credential flows for security

### Python Utilities Architecture
- `shared/utils.py` - Core utilities for Azure resource management, deployment, cleanup with colored output formatting
- `shared/apimtools.py` - APIM-specific client tools and API discovery using Azure SDK
- Standardized `print_*` functions for consistent output formatting (print_ok, print_error, print_info, etc.)
- Resource lifecycle management integrated with Azure CLI commands
- APIM policy management via REST APIs and Azure Management SDK

## Development Guidelines

### Code Style
- Python follows PEP 8 conventions
- Bicep templates use descriptive parameter names and documentation
- XML policies are properly formatted and commented
- Jupyter notebooks include markdown explanations

### Resource Naming
- Use `resourceSuffix` parameter for unique naming
- Follow Azure naming conventions
- Include resource type prefixes (apim-, ai-, kv-, etc.)

### Security Practices  
- Use Azure Managed Identity where possible
- Store secrets in Key Vault
- Implement proper RBAC permissions
- Follow principle of least privilege

### Lab Testing and Validation
- Each lab is self-contained with its own infrastructure and cleanup
- Every lab includes a `clean-up-resources.ipynb` notebook that MUST be run after testing
- Validation is done through notebook execution and checking response outputs
- Resource cleanup includes purging soft-deleted Azure resources (APIM, Cognitive Services, Key Vault)
- Use debug tracing tools in `tools/` directory for troubleshooting API calls
- Test files use `.rest`, `.http`, and PowerShell scripts for API validation

## Notable Dependencies

- **Azure CLI** - Primary interface for Azure operations
- **Bicep** - Infrastructure as Code templates
- **Azure SDK for Python** - Programmatic Azure resource management
- **OpenAI Python SDK** - AI model interactions
- **MCP (Model Context Protocol)** - Agent and tool integration
- **AutoGen** - Multi-agent conversation frameworks
- **Semantic Kernel** - AI application orchestration

## Development Workflow

### Lab Development Process
1. Navigate to the specific lab directory: `cd labs/<lab-name>`
2. Deploy infrastructure using `main.bicep` template
3. Execute the lab notebook step-by-step for testing and validation
4. **Always run `clean-up-resources.ipynb` when finished** to avoid resource charges
5. Update documentation if making changes to lab functionality

### Git Workflow
- Standard branch-based workflow from main branch
- Each lab is self-contained and must remain functional
- Always include both implementation and cleanup procedures
- Test lab functionality end-to-end before committing
- Sensitive files: use `.gitignore` or `git update-index --skip-worktree` for tracked files (see `scripts/git-helpers.md`)

### Working with Shared Components
- Modify `shared/utils.py` or `shared/apimtools.py` carefully as they affect all labs
- Test changes across multiple labs before committing shared utility changes
- Follow existing patterns for output formatting and error handling