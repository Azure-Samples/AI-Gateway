# Pydantic AI Agent on Foundry Hosted Agents

This sample shows how to build, deploy, and test a Pydantic AI-based custom agent on Microsoft Foundry Hosted Agents using the Responses protocol v1.0.0.

## Framework Overview (Pydantic AI)

According to the official Pydantic AI agent docs, an agent is the primary abstraction and can be treated as a container for instructions, tools/toolsets, structured output typing, dependency typing, model settings, and reusable capabilities.

Why that matters for this sample:
- Good fit when output shape and validation matter to downstream systems.
- Good fit when you want typed dependencies and strong IDE/static-checker feedback.
- Good fit when you want to compose reusable behavior via capabilities.

Official reference:
- https://pydantic.dev/docs/ai/core-concepts/agent/

![Pydantic AI Hosted Agent Sample](image.png)

## What Is Included

- `main.py`: Pydantic AI agent server implementation (Responses protocol + tool calling + streaming).
- `Dockerfile`: Container definition for hosting the agent in Foundry Hosted Agents.
- `requirements-pydantic.txt`: Python dependencies for this runtime.
- `../../../../ai-foundry-hosted-agents-custom-framework.ipynb`: End-to-end lab notebook (set `framework = 'pydantic'`).

## Get Started

1. Open the lab notebook `../../../../ai-foundry-hosted-agents-custom-framework.ipynb` and set `framework = 'pydantic'` in the initialization cell.
2. Run the notebook from top to bottom.
3. It builds and pushes the container image to Azure Container Registry with `az acr build`.
4. It creates a hosted agent version in your Foundry project.
5. It validates the agent through:
	- Direct Foundry call (baseline)
	- APIM call (production-like path)

## Prerequisites

- Azure subscription with access to Microsoft Foundry and Azure Container Registry.
- Permission to push images to the target ACR repository.
- Permission to create hosted agent versions in Foundry.
- Azure CLI installed and authenticated (`az login`).
- Python environment with dependencies required by this sample.

## Invocation and Routing

Hosted agents are invoked by agent-specific URL path.

Direct Foundry endpoint:

```http
POST {PROJECT_ENDPOINT}/agents/{AGENT_NAME}/endpoint/protocols/openai/responses?api-version=v1
```

APIM endpoint:

```http
POST https://apim-{APIM_SUFFIX}.azure-api.net/hosted-agent-responses/agents/{AGENT_NAME}/endpoint/protocols/openai/responses?api-version=v1
```

- Do not use `agent_reference` in the request body for hosted-agent routing.
- Use `api-key` header when calling APIM.
- Include `Content-Type: application/json`.

## Notes

- This sample routes model calls through APIM inference (`/inference/models`).
- Configure `AZURE_OPENAI_ENDPOINT` to your APIM inference URL and set `APIM_SUBSCRIPTION_KEY`.
- The runtime sends the APIM subscription key in the `api-key` header for model calls.
- Keep notebook placeholder values aligned with your infrastructure deployment outputs.
