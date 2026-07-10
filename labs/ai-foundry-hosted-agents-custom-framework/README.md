---
name: "AI Foundry Hosted Agents (Custom Frameworks)"
architectureDiagram: images/ai-foundry-hosted-agents.gif
categories:
  - AI Agents
services:
  - Microsoft Foundry
  - Hosted Agents
  - Azure API Management
  - Container Registry
shortDescription: Deploy AI Foundry Hosted Agents built with custom frameworks, including Pydantic AI and Strands.
detailedDescription: This lab provides custom framework examples for AI Foundry Hosted Agents, showing how to package and deploy hosted agents built with Pydantic AI and Strands. It includes a Bicep deployment for Azure API Management, Azure AI Foundry resources, and a GPT-5-Mini model deployment, plus a single end-to-end notebook and Dockerfiles.
authors:
  - georgeollis
tags: []
---

# APIM ❤️ AI Foundry

## AI Foundry Hosted Agents with Custom Frameworks

This lab extends the Hosted Agents scenario with framework-specific examples so you can build agents using your preferred runtime while keeping a common deployment pattern.

### Why run custom frameworks on Foundry Hosted Agents?

1. Built-in observability, tracing, and monitoring.
Foundry provides a standard operational surface for agent runs, telemetry, and diagnostics so teams can troubleshoot faster and keep a consistent monitoring model across different agent runtimes.

2. Agent Identity and RBAC by default.
Your runtime is registered as a Foundry Agent and gets an Agent Identity, enabling least-privilege access to downstream Azure resources (for example, storage, search, or APIs) through RBAC instead of embedded secrets.

3. Foundry guardrails and governance.
Hosted agents can inherit platform safety controls and governance policies, helping you enforce security and compliance consistently even when the runtime framework is custom.

4. Discovery through Agent365.
Publishing into the Foundry ecosystem makes agents easier to discover and reuse across teams, reducing duplicate implementations.

5. Native evaluation and risk testing integration.
You can plug directly into Foundry evaluations, red teaming, and cost-estimation workflows to compare quality, safety, and spend using the same platform tooling.

6. Control plane and platform operations.
Agents are managed as platform assets in the Foundry control plane, with operational benefits such as managed hosting lifecycle, scaling, and centralized administration.

### When custom frameworks are a good fit

- You need framework-specific capabilities (for example, Pydantic AI or Strands primitives) not available in a default runtime.
- You want framework flexibility without giving up Foundry governance and enterprise operations.
- You need to standardize deployment and operations across multiple agent implementations.

## Lab Notebook

The lab runs end-to-end from a single notebook. Set the `framework` variable (`strands` or `pydantic`) in the initialization cell to choose which custom-framework agent to build and deploy:

- [ai-foundry-hosted-agents-custom-framework.ipynb](ai-foundry-hosted-agents-custom-framework.ipynb)

It deploys the infrastructure with Bicep, builds and pushes the agent image, registers the hosted agent in Foundry, and tests it both directly and through APIM.

### What gets deployed

Core services:
- Azure API Management (APIM) as gateway and reverse proxy
- Microsoft Foundry resources (two AI Services resources):
  - foundry-models: hosts inference models used by agents
  - foundry-agents: hosts your custom framework runtimes via Hosted Agents Responses protocol v1.0.0
- Azure Container Registry (ACR) for agent container images
- Application Insights and Log Analytics for observability

RBAC and access control:
- ACR repository permissions for the hosted-agent Foundry resource (Container Registry Repository Reader + AcrPull)
- ACR repository permissions for the deploying user (Container Registry Repository Writer + Container Registry Repository Catalog Lister)
- Foundry User role assignments for configured user object IDs across Foundry resources

APIM proxy configuration (optional, enabled when enableHostedAgentResponsesApi=true):
- Dedicated API endpoint proxying Foundry Hosted Agent Responses
- Managed identity token injection for Foundry authentication
- Header injection/enforcement:
  - Content-Type: application/json
  - Foundry-Features: HostedAgents=V1Preview
- Uses APIM subscription key for client authentication
- Supports multiple agents without APIM reconfiguration by using agent-specific URL paths

Policy definition is in [hosted-agent-policy.xml](hosted-agent-policy.xml).

The deployment template is in [main.bicep](main.bicep).

## Framework Samples

- [Frameworks Overview](src/responses/agents/frameworks/README.md)
- [Strands Framework](src/responses/agents/frameworks/strands/README.md)
- [Pydantic AI Framework](src/responses/agents/frameworks/pydantic/README.md)

## Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [uv](https://docs.astral.sh/uv/) — run `uv sync` from the repo root to install dependencies
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

> The agent container image is built in Azure Container Registry with `az acr build`, so a local Docker installation is not required.

## Get Started

Proceed by opening the [Jupyter notebook](ai-foundry-hosted-agents-custom-framework.ipynb) and follow the steps provided.

The notebook runs top-to-bottom and:

1. Deploys the infrastructure with Bicep (Foundry resources, APIM, ACR, monitoring).
2. Builds and pushes the selected framework's agent image to ACR with `az acr build`.
3. Registers the container image as a Foundry Hosted Agent.
4. Tests the agent directly against Foundry and through APIM.

Set the `framework` variable in the initialization cell to `strands` or `pydantic` to switch frameworks, then re-run the build, deploy, and test cells.

Invoke a deployed agent through APIM using agent-specific URL path routing:

```http
POST https://apim-{suffix}.azure-api.net/hosted-agent-responses/agents/{agentName}/endpoint/protocols/openai/responses?api-version=v1
api-key: {subscription-key}
Content-Type: application/json
```

Example body:

```json
{
  "input": "Hello! What can you help me with?",
  "stream": false
}
```

- Replace {agentName} to target a different deployed agent.
- Do not use agent_reference in the request body for hosted-agent routing.

## Test Flow Explained

Direct test:
- Calls the Foundry Hosted Agent Responses API directly
- Uses a bearer token from the Azure CLI credential with audience https://ai.azure.com/.default
- Best baseline for runtime/connectivity troubleshooting

APIM test:
- Routes through APIM using the subscription key (api-key)
- APIM injects the managed identity token and required headers
- Validates the production-like client -> APIM -> Foundry path

## Clean Up Resources

Use [clean-up-resources.ipynb](clean-up-resources.ipynb) when finished.

## Troubleshooting

If direct test fails:
- Verify agent status is Running in Foundry
- Verify Azure CLI authentication (az login)
- Confirm PROJECT_ENDPOINT is correct
- Check networking/firewall constraints

If APIM test fails but direct test succeeds:
- Verify APIM suffix and subscription key
- Check [hosted-agent-policy.xml](hosted-agent-policy.xml) token audience (https://ai.azure.com)
- Use APIM Trace in Azure Portal to inspect policy and backend flow

If container startup fails:
- Verify Foundry identity has AcrPull access
- Verify pushed image URI matches agent definition
- Check Foundry diagnostics and Application Insights

## References

- [Microsoft Foundry Documentation](https://learn.microsoft.com/en-us/foundry/)
- [Hosted Agents Responses Protocol](https://learn.microsoft.com/en-us/azure/ai-studio/ai-services/agents/protocols/responses)
- [APIM Authentication Policies](https://learn.microsoft.com/en-us/azure/api-management/policies/authentication-policies)
