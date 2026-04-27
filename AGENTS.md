# AGENTS.md

This document describes the key directories in the AI Gateway workspace for AI coding agents.

## Overview

The **AI Gateway** is an experimental repository exploring the AI Gateway pattern through Azure API Management. It focuses on managing AI services APIs with security, reliability, performance, and cost controls. Labs use Jupyter notebooks with Python, Bicep templates, and Azure API Management policies.

---

## Directory Structure

### `labs/`

Contains hands-on experimental labs, each in its own subdirectory. Labs are structured as Jupyter notebooks with supporting Bicep infrastructure files and APIM policies.

**Categories of labs include:**

- **AI Agents & MCP**: `model-context-protocol/`, `mcp-client-authorization/`, `mcp-a2a-agents/`, `mcp-from-api/`, `mcp-prm-oauth/`, `mcp-registry-apic/`, `openai-agents/`, `ai-agent-service/`, `realtime-mcp-agents/`, `gemini-mcp-agents/`
- **Model Integration**: `ai-foundry-sdk/`, `ai-foundry-deepseek/`, `ai-foundry-private-mcp/`, `gemini-models/`, `aws-bedrock/`, `slm-self-hosting/`
- **Load Balancing & Routing**: `backend-pool-load-balancing/`, `backend-pool-load-balancing-tf/`, `model-routing/`
- **Security & Access Control**: `access-controlling/`, `content-safety/`, `private-connectivity/`, `secure-responses-api/`
- **Monitoring & Logging**: `built-in-logging/`, `token-metrics-emitting/`
- **Rate Limiting & Caching**: `token-rate-limiting/`, `semantic-caching/`
- **Specialized Features**: `realtime-audio/`, `image-generation/`, `function-calling/`, `vector-searching/`, `message-storing/`, `session-awareness/`
- **Operations**: `finops-framework/`, `zero-to-production/`

**Lab structure pattern:**

- `README.md` - README file to describe lab following the standard lab structure.
- `<lab-name>.ipynb` - Main Jupyter notebook with step-by-step instructions
- `clean-up-resources.ipynb` - Jupyter notebooks used to removed resources when the lab is finished
- `main.bicep` - Azure infrastructure deployment template
- `params.json` - Temporary file generated automatically for the bicep deployment. This file will not be commited to the repo.
- `*policy.xml` - Azure API Management policy files
- `src/` - Supporting source code (when applicable)

Disregard the `labs/_deprecated` folder, as it contains archived labs.

---

### `modules/`

Contains reusable Bicep modules for Azure resource deployment. These are referenced by labs' `main.bicep` files.

| Subdirectory | Purpose |
|--------------|---------|
| `apim/` | Azure API Management deployment modules (v1, v2, v3 versions) |
| `apim-streamable-mcp/` | APIM module with MCP streaming support |
| `apic/` | Azure API Center deployment modules |
| `cognitive-services/` | Azure Cognitive Services deployment modules (v1, v2, v3 versions) |
| `monitor/` | Azure Monitor resource modules |
| `network/` | Networking infrastructure modules |
| `operational-insights/` | Log Analytics workspace modules |

**Supporting files:**

- `azure-roles.json` - Azure RBAC role definitions used across modules

---

### `shared/`

Contains shared Python utilities and reusable code used across multiple labs.

| File/Directory | Purpose |
|----------------|---------|
| `utils.py` | Core utility functions: Azure CLI command execution, resource retrieval, formatted console output (print_ok, print_error, print_info, etc.) |
| `apimtools.py` | `APIMClientTool` class for Azure API Management operations: client initialization, API discovery, subscription key management |
| `snippets/` | Reusable Python code snippets loaded into notebooks via `%load` magic command |
| `mcp-servers/` | Sample MCP server implementations (`weather/`, `spotify/`, `github/`, `oncall/`, `prm-graphapi/`) |

**Snippets usage:**

Labs reference `utils` library using Python:

```python
import os, sys, json
sys.path.insert(1, '../../shared')  # add the shared directory to the Python path
import utils

```

---

### `tools/`

Contains standalone utility notebooks and testing tools for use with deployed labs.

| File | Purpose |
|------|---------|
| `tracing.ipynb` | Invoke AI Foundry model APIs with tracing enabled |
| `streaming.ipynb` | Test streaming responses from AI models |
| `rate-limit.ipynb` | Test rate limiting configurations |
| `test-ai-gateway.ipynb` | General AI Gateway testing utility |
| `test-sequence.ipynb` | Sequential testing of API calls |
| `client-oauth.ipynb` | OAuth client authentication testing |
| `mock-server/` | Mock OpenAI API server for development and testing |
| `sample-prompts.json` | Sample prompts for testing |

---

## Key Technologies

- **Language**: Python 3.12+
- **Notebooks**: Jupyter notebooks (`.ipynb`)
- **Infrastructure**: Azure Bicep templates (`.bicep`)
- **Policies**: Azure API Management XML policies (`.xml`)
- **Azure Services**: API Management, Microsoft Foundry, Azure API Center, Azure Monitor and other Azure services

## Prerequisites

- Python 3.12+ with dependencies from `requirements.txt`
- Azure CLI authenticated to an Azure subscription
- VS Code with Jupyter extension
- Azure subscription with appropriate RBAC permissions
