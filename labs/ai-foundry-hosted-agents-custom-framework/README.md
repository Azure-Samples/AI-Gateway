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
detailedDescription: This lab provides custom framework examples for AI Foundry Hosted Agents, showing how to package and deploy hosted agents built with Pydantic AI and Strands to Azure Container Apps. It includes a Bicep deployment for Azure API Management, Azure AI Foundry, and a GPT-5-Mini model deployment, plus end-to-end setup notebooks and Dockerfiles.
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

## [Infrastructure deployment notebook](ai-foundry-hosted-agents-custom-framework.ipynb)

Use this notebook first to deploy core infrastructure with Bicep.

### What gets deployed

**Core Services:**
- Azure API Management (APIM) - Acts as the gateway and reverse proxy
- Microsoft Foundry (two separate AI Services resources):
  - **foundry-models**: Hosts inference models (GPT-5-Mini) for your agents to use
  - **foundry-agents**: Hosts your custom framework agent runtimes via Hosted Agents Responses protocol v1.0.0
- Azure Container Registry (ACR) - Stores your agent container images
- Application Insights & Log Analytics - Provides observability and diagnostics

**RBAC & Access Control:**
- ACR repository permissions for the hosted-agent Foundry resource (`Container Registry Repository Reader` + `AcrPull`)
- ACR repository permissions for the deploying user (`Container Registry Repository Writer` + `Container Registry Repository Catalog Lister`)
- Foundry User role assignments (`Foundry User`) for configured user object IDs across all Foundry resources

**APIM Proxy Configuration** (optional, added when `enableHostedAgentResponsesApi=true`):
- Dedicated API endpoint proxying Foundry's Responses API
- **Dynamic Agent Routing**: Clients specify the target agent via `agent_reference` in the request body (not the URL)
- Managed identity token injection (Foundry authentication)
- Automatic header injection:
  - `Content-Type: application/json`
  - `Foundry-Features: HostedAgents=V1Preview` (required for preview access)
- Automatic query parameter enforcement:
  - `api-version: 2025-05-15-preview`
- Uses APIM subscription key for client authentication (cleaner than managing bearer tokens on client side)
- **Agent-Agnostic Design**: Works with any deployed agent—no need to reconfigure APIM when you add a new agent

Policy definition is in [hosted-agent-policy.xml](hosted-agent-policy.xml) for easy customization.

The deployment template is in [main.bicep](main.bicep).

### Available samples

- [Pydantic AI sample](src/responses/agents/pydantic-ai/README.md)
- [Strands sample](src/responses/agents/strands/README.md)

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- Python dependencies: Install via `pip install azure-ai-projects azure-identity requests` (or run the dependency cell in each notebook)
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)
- [Docker](https://www.docker.com/get-started/) installed and running (for building container images)

### Get started

**Step 1: Deploy Infrastructure**
- Run all cells in [ai-foundry-hosted-agents-custom-framework.ipynb](ai-foundry-hosted-agents-custom-framework.ipynb)
- This creates your Foundry resources, APIM, ACR, and monitoring infrastructure
- Note the outputs (Foundry endpoints, ACR login server, APIM URL) for the next steps

**Step 2: Choose & Deploy Your Agent**
- Pick one of the sample frameworks: [Pydantic AI](src/responses/agents/pydantic-ai/README.md) or [Strands](src/responses/agents/strands/README.md)
- Open the corresponding setup notebook and run all cells:
  1. Build the Docker container image for your agent framework
  2. Push the image to ACR
  3. Create a hosted agent version in your Foundry project
  4. Test the agent directly via Foundry's Responses API (baseline validation)
  5. Test the agent via APIM (validates the proxy gateway)

**Step 3: Test via APIM (Optional)**
- APIM is automatically configured for any deployed agent
- In the sample agent notebooks (Section 4), clients specify the target agent via `agent_reference` in the request body
- Request format:
  ```json
  POST https://apim-{suffix}.azure-api.net/hosted-agent-responses/responses
  Headers: api-key: {subscription-key}
  Body: {
    "agent_reference": { "type": "agent_reference", "name": "strands-agent", "version": "1" },
    "input": "Your prompt",
    "model": "gpt-5-mini"
  }
  ```
- Once you deploy additional agents to Foundry, simply change `agent_reference.name` in the request—no APIM reconfiguration needed

### Test Flow Explained

Each sample notebook includes three test scenarios:

1. **Direct Foundry Test** (Section 3)
   - Calls the Foundry Hosted Agent Responses API directly with agent name in URL
   - Uses your Azure CLI credential (bearer token with `https://ai.azure.com/.default` audience)
   - Validates the agent runtime and basic connectivity
   - No APIM involvement—good baseline for troubleshooting

2. **APIM Test** (Section 4)
   - Routes through APIM gateway using subscription key (`api-key` header)
   - Specifies the target agent via `agent_reference` in the request body (not the URL)
   - APIM injects managed identity token to Foundry automatically
   - APIM enforces `Content-Type`, `Foundry-Features`, and `api-version` headers
   - Tests the full production-like path (client → APIM → Foundry agent)
   - **Key difference**: You can change `agent_reference.name` to target different agents without reconfiguring APIM

### Clean up resources

Use the [clean-up-resources notebook](clean-up-resources.ipynb) to remove deployed resources when you are finished.

### Troubleshooting

**Section 3 (Direct Test) fails:**
- Check agent status in Foundry—should be "Running"
- Verify you're logged into Azure CLI (`az login`)
- Confirm the `PROJECT_ENDPOINT` is correct from the infrastructure deployment
- Check network connectivity (firewall, proxy)

**Section 4 (APIM Test) fails but Section 3 succeeds:**
- Verify `APIM_SUFFIX` matches your APIM instance name
- Confirm `APIM_SUBSCRIPTION_KEY` is correct
- Check APIM policy in `hosted-agent-policy.xml`—ensure token audience is `https://ai.azure.com`
- Use APIM's TRACE tool to debug the request flow:
  - In Azure Portal → APIM → Diagnose and solve problems → Trace
  - Re-run your test and examine the detailed trace output
  - Look for authentication errors, backend routing issues, or header mismatches

**Agent container fails to start:**
- Check ACR permissions—Foundry resource identity needs `AcrPull` role
- Verify the container image URI in Foundry matches what you pushed to ACR
- Check logs via Foundry's diagnostics or Application Insights

**For more help:**
- Review the [APIM policy file](hosted-agent-policy.xml) to understand header/parameter enforcement
- Check [Bicep template](main.bicep) for resource configuration details
- Consult [Microsoft Foundry documentation](https://learn.microsoft.com/en-us/foundry/)
