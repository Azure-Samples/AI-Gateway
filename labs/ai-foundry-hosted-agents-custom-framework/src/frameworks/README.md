# Hosted Agent Frameworks

This directory contains multiple framework implementations for deploying custom agents on **Microsoft Foundry Hosted Agents**.

## Quick Start

1. **Choose your framework** in the lab notebook by setting the `framework` variable to `strands` or `pydantic`:
   - [**Strands Framework**](#strands-framework)
   - [**Pydantic AI Framework**](#pydantic-ai-framework)

2. **Run the lab notebook** [ai-foundry-hosted-agents-custom-framework.ipynb](../../../../ai-foundry-hosted-agents-custom-framework.ipynb) top-to-bottom. It deploys the infrastructure, builds the selected framework's image, registers the hosted agent, and tests it directly and through APIM.

## Framework Overview

### Strands Agents

https://strandsagents.com/

### Pydantic AI

https://pydantic.dev/docs/ai/core-concepts/agent/

## Folder Structure

```
frameworks/
├── strands/                                  # Strands framework implementation
│   ├── main.py                               # Agent entry point
│   ├── Dockerfile                            # Container image definition
│   ├── requirements-strands.txt              # Strands framework dependencies
│   ├── README.md                             # Strands-specific documentation
│   ├── example.env                           # Environment variables template
│   ├── .gitignore
│   └── .dockerignore
│
└── pydantic/                                 # Pydantic AI framework implementation
    ├── main.py                               # Agent entry point
    ├── Dockerfile                            # Container image definition
    ├── requirements-pydantic.txt             # Pydantic dependencies
    ├── README.md                             # Pydantic-specific documentation
    ├── example.env                           # Environment variables template
    ├── .gitignore
    └── .dockerignore
```

## Strands Framework

**Best for**: Custom agent logic with full control over request/response handling

### What it is
- Custom framework for building agents with structured responses
- Direct control over agent behavior and response formatting
- Ideal for domain-specific agent implementations

### How it works (in the lab notebook, `framework = 'strands'`)
1. **Builds the image in ACR** from the `strands/` directory with `az acr build`
2. **Deploys to Foundry** using the image from ACR
3. **Tests direct API** - calls Foundry Responses API with bearer token
4. **Tests via APIM** - routes through API Management gateway with subscription key

### Key Files
- `main.py` - Agent execution and response protocol handler
- `requirements-strands.txt` - Framework-specific dependencies
- `Dockerfile` - Container image with `FROM python:3.12-slim`

### Getting Started
```python
# Run notebook cells in order:
# 1. Build and push Docker image to ACR
# 2. Create hosted agent version in Foundry
# 3. Test direct API call (validates agent is running)
# 4. Test through APIM (validates gateway routing)
```

## Pydantic AI Framework

**Best for**: LLM-powered agents with automatic input/output validation

### What it is
- Lightweight LLM framework with built-in type safety
- Automatic request/response validation via Pydantic models
- Streamlined agent development with minimal boilerplate

### How it works (in the lab notebook, `framework = 'pydantic'`)
1. **Builds the image in ACR** from the `pydantic/` directory with `az acr build`
2. **Deploys to Foundry** using the image from ACR
3. **Tests direct API** - calls Foundry Responses API with bearer token
4. **Tests via APIM** - routes through API Management gateway with subscription key

### Key Files
- `main.py` - Pydantic-based agent with validation
- `requirements-pydantic.txt` - Pydantic and related dependencies
- `Dockerfile` - Container image with `FROM python:3.12-slim`

### Getting Started
```python
# Run notebook cells in order:
# 1. Build and push Docker image to ACR
# 2. Create hosted agent version in Foundry
# 3. Test direct API call (validates agent is running)
# 4. Test through APIM (validates gateway routing)
```

## Important: Foundry Hosted Agent URL Format

**Agent-specific routing is required** — there is no generic `/responses` endpoint that accepts `agent_reference` in the request body.

Each agent must be invoked with its name in the URL path:

```
POST {FOUNDRY_ENDPOINT}/agents/{AGENT_NAME}/endpoint/protocols/openai/responses?api-version=v1
```

**Through APIM Gateway:**
```
POST https://apim-{APIM_SUFFIX}.azure-api.net/hosted-agent-responses/agents/{AGENT_NAME}/endpoint/protocols/openai/responses?api-version=v1
```

- `AGENT_NAME` - The name you choose when creating the agent (e.g., `strands-agent`, `pydantic-agent`)
- `api-version=v1` - Required query parameter for Responses protocol v1.0.0

## Environment Configuration

Both frameworks expect these environment variables (set in Foundry agent definition):

| Variable | Purpose | Example |
|----------|---------|---------|
| `AZURE_OPENAI_ENDPOINT` | APIM inference API for model calls | `https://apim-xyz.azure-api.net/inference/models` |
| `AZURE_OPENAI_API_VERSION` | OpenAI API version | `2024-05-01-preview` |
| `AZURE_OPENAI_DEPLOYMENT` | Model name | `gpt-5-mini` |
| `APIM_SUBSCRIPTION_KEY` | APIM subscription key | (from deployment outputs) |

## Workflow: Direct vs APIM

### Direct Call
- **URL**: `https://foundry-agents-{suffix}.services.ai.azure.com/api/projects/default-foundry-agents/agents/{AGENT_NAME}/endpoint/protocols/openai/responses?api-version=v1`
- **Auth**: Bearer token (from `az login` → `https://ai.azure.com/.default`)
- **Use case**: Development, validation that agent is running correctly
- **Pros**: Direct connection, best for debugging
- **Cons**: Requires Azure credentials on client

### APIM Gateway
- **URL**: `https://apim-{APIM_SUFFIX}.azure-api.net/hosted-agent-responses/agents/{AGENT_NAME}/endpoint/protocols/openai/responses?api-version=v1`
- **Auth**: API key header (`api-key: <subscription-key>`)
- **Use case**: Production, client applications, rate limiting, monitoring
- **Pros**: Gateway features (caching, rate limiting, analytics), simpler auth
- **Cons**: One extra hop through APIM

## Adding a New Framework

To add another framework (e.g., CrewAI, AutoGen):

1. **Create folder**: `mkdir frameworks/crew-ai`
2. **Copy template files**:
   - Copy `Dockerfile` from existing framework
   - Create `main.py` with your framework initialization
   - Create `requirements-crew-ai.txt` with framework dependencies
   - Create `README.md` documenting the framework
3. **Register the framework in the lab notebook**: add an entry to the `frameworks` map in the initialization cell, for example `'crew-ai': {'agent_name': 'crew-ai-agent', 'image': 'crew-ai-agent'}`, then set `framework = 'crew-ai'` and re-run the build, deploy, and test cells.
4. **Update deployment**: If deploying multiple agents, register them with different names.

## Testing Your Agent

After deployment, verify your agent works:

```bash
# 1. Ensure agent is in "Running" state (check Foundry portal)
# 2. Run Section 3 (Direct) test
# 3. Run Section 4 (APIM) test
# 4. Compare responses - they should be identical
```

Successful response structure:
```json
{
  "id": "caresp_...",
  "object": "response",
  "output": [{
    "type": "message",
    "role": "assistant",
    "content": [{
      "type": "output_text",
      "text": "Agent's response text..."
    }]
  }],
  "status": "completed"
}
```

## Troubleshooting

### "Agent endpoint not found"
- Verify agent name in URL matches the agent name created in Foundry
- Ensure agent is in "Running" state (not "Creating", "Failed", etc.)

### "api-version query parameter is not allowed"
- Ensure you're using `/v1` path, not `/v2`
- Don't include `api-version` in APIM policy - use it only in URL

### "Managed identity does not have access to Azure AI"
- Verify Foundry project's managed identity has proper role assignment
- Check APIM managed identity has `Contributor` or `Cognitive Services User` role

### Agent not receiving requests
- Check the image builds successfully in ACR: `az acr build --registry {registry} --image test:1.0 .`
- Verify APIM policy correctly injects authentication headers
- Check ACR image is pullable by Foundry (check image pull errors in Foundry portal)

## References

- [Microsoft Foundry Hosted Agents Documentation](https://learn.microsoft.com/en-us/azure/ai-studio/ai-services/agents/)
- [Responses Protocol v1.0.0 Specification](https://learn.microsoft.com/en-us/azure/ai-studio/ai-services/agents/protocols/responses)
- [APIM Policies for Authentication](https://learn.microsoft.com/en-us/azure/api-management/policies/authentication-policies)
