# Strands Agent on Foundry Hosted Agents

This sample shows how to build, deploy, and test a **Strands-based custom agent** on Microsoft Foundry Hosted Agents using the **Responses protocol v1.0.0**.

## Framework Overview (Strands)

From the official Strands site, Strands is an open-source toolkit focused on building production agents with model/provider flexibility, built-in context management, execution limits, observability, and hook-based runtime control.

Why that matters for this sample:
- Good fit for tool-heavy workflow automation.
- Good fit when you want to intercept/steer runtime behavior with hooks.
- Good fit when operational visibility and control of the agent loop are top priorities.

Official reference:
- https://strandsagents.com/

The agent runs in a containerized environment managed by Foundry, with full observability, RBAC identity, and optional APIM gateway integration.

![Strands Hosted Agent Sample](image.png)

## What Is Included

- **`main.py`**: Strands agent server implementing the Responses protocol with tool calling and streaming.
- **`Dockerfile`**: Container image definition for Foundry Hosted Agents (builds for Linux amd64).
- **`requirements-strands.txt`**: Python dependencies (Strands, FastAPI, etc.).
- **`01_hosted_agent_strands_setup.ipynb`**: End-to-end setup and testing notebook with 4 sections:
  1. Build and push container to ACR
  2. Create hosted agent version in Foundry
  3. Test agent directly via Foundry Responses API (baseline validation)
  4. Test agent via APIM gateway (production-like path with managed identity auth)

## How It Works

### Responses Protocol

Your Strands agent implements the **Responses protocol v1.0.0**, which is Foundry's standard for hosted agents:
- HTTP-based request/response model (no WebSocket or streaming required for basic cases)
- Request: `POST /endpoint/protocols/openai/responses?api-version=v1`
- Request body: `{ "input": "<user message>", "stream": false }`
- Response: `{ "output_text": "<agent response>" }` (or streaming deltas)

Your Foundry project manages the deployment, scaling, health checks, and lifecycle.

### Deployment Architecture

```
Client 
  ↓
APIM Gateway (managed identity injection, header/param enforcement)
  ↓
Foundry Hosted Agent (runs your Strands container)
  ↓
APIM Inference API (agent calls models via this endpoint)
  ↓
OpenAI (GPT-5-Mini)
```

**Authentication flow:**
- Client → APIM: Use `api-key` header (APIM subscription key)
- APIM → Foundry: APIM's managed identity fetches bearer token for `https://ai.azure.com`
- Agent → Models: Agent uses APIM inference endpoint with its own APIM subscription key

## Get Started

### Step 1: Configure Your Setup

Open `01_hosted_agent_strands_setup.ipynb` and fill in the configuration variables at the top:
- `ACR_NAME`: Your Azure Container Registry name
- `IMAGE_NAME`: Container image name (usually `strands-agent`)
- `IMAGE_TAG`: Semantic version (e.g., `1.0.0`)
- `PROJECT_ENDPOINT`: Foundry project endpoint (from infrastructure deployment)
- `AZURE_OPENAI_ENDPOINT`: APIM inference API endpoint
- `APIM_SUBSCRIPTION_KEY`: APIM subscription key
- `APIM_SUFFIX`: Your APIM instance suffix

### Step 2: Build & Push Container

Run **Section 1** of the notebook:
- Builds a Docker image: `docker build -t {ACR_URI} --platform linux/amd64 .`
- Pushes to ACR: `docker push {ACR_URI}`

The `--platform linux/amd64` flag ensures compatibility with Foundry's Linux hosting.

### Step 3: Create Hosted Agent

Run **Section 2** of the notebook:
- Creates a HostedAgentDefinition with your container image
- Specifies resource allocation (1 CPU, 2Gi memory)
- Sets environment variables for your agent to reach models
- Foundry automatically pulls the image and starts your container

Once the agent transitions to "Running" state, it's ready for testing.

### Step 4: Validate Agent Locally

Run **Section 3** ("Test Direct"):
- Calls Foundry's Responses API directly using your Azure CLI credential
- No APIM involvement—validates agent and basic connectivity
- Helpful for troubleshooting deployment issues

If this test fails, check agent status in Foundry or review container logs.

### Step 5: Test via APIM Gateway (Production Path)

Run **Section 4** ("Test via APIM"):
- Routes through APIM gateway using `api-key` header
- APIM automatically:
  - Injects managed identity bearer token
  - Enforces `Content-Type: application/json`
  - Uses Responses API `api-version=v1`
  - Injects `Foundry-Features: HostedAgents=V1Preview` (required for preview)
- Validates end-to-end production path

Policy configuration is in `../../hosted-agent-policy.xml` for customization.

## Prerequisites

- Microsoft Foundry resources deployed (see parent [infrastructure notebook](../../ai-foundry-hosted-agents-custom-framework.ipynb))
- Azure CLI installed and authenticated (`az login`)
- Docker Desktop installed and running
- Python 3.12+ with dependencies: `pip install azure-ai-projects azure-identity requests`
- Azure subscription with permissions to:
  - Push images to ACR
  - Create agent versions in Foundry
  - Assign roles (for RBAC setup)

## Key Configuration Notes

- **Agent name**: Use the same value configured as `AGENT_NAME` in the setup notebook.
- **Model endpoint**: Your agent calls the APIM **inference** API, not the hosted-agent API.
- **Token audience**: 
  - Direct tests use `https://ai.azure.com/.default`
  - APIM uses `https://ai.azure.com` (managed identity)
- **No hard-coded API keys in agent**: The agent gets credentials through environment variables injected at deployment time.

## Monitoring & Debugging

- **Application Insights**: Monitor traces, dependencies, and performance
- **APIM Trace Tool**: In Azure Portal → APIM → Diagnose and solve problems → Trace
  - Re-run a test while tracing to see detailed request/response flow
  - Useful for debugging authentication, routing, or header issues
- **Foundry Agent Details**: View agent status, logs, and deployment history in Foundry portal

## Testing Patterns

**If Section 3 works but Section 4 fails:**
- APIM policy issue likely (verify `hosted-agent-policy.xml`)
- Use APIM Trace to inspect inbound/outbound traffic
- Check managed identity token generation

**If both tests fail:**
- Agent may not be in "Running" state
- Check ACR image URI and permissions
- Review Foundry agent logs for startup errors
