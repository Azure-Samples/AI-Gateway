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
	- nourshaker-msft
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

Use this notebook first to deploy core infrastructure with Bicep:

- Azure API Management (APIM)
- Microsoft Foundry (two foundry resources: models + hosted agents)
- GPT-5-Mini model deployment
- Azure Container Registry (ACR) for hosted agent images

The deployment also configures:

- ACR repository permissions for the hosted-agent Foundry resource and its project identity (`Container Registry Repository Reader`)
- ACR repository permissions for the deploying user (`Container Registry Repository Writer` + `Container Registry Repository Catalog Lister`)
- Foundry User role assignments (`Foundry User`) for configured user object IDs across all Foundry resources deployed by this lab
- Optional APIM proxy API for the Hosted Agent Responses endpoint, added after the hosted agent has been deployed and is running

The deployment template is in [main.bicep](main.bicep).

### Available samples

- [Pydantic AI sample](src/responses/agents/pydantic-ai/README.md)
- [Strands sample](src/responses/agents/strands/README.md)

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [uv](https://docs.astral.sh/uv/) - run `uv sync` from the repo root to install dependencies
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)
- [Docker](https://www.docker.com/get-started/) installed and running (for building container images)

### Get started

1. Run the [infrastructure deployment notebook](ai-foundry-hosted-agents-custom-framework.ipynb).
2. Choose one of the sample frameworks above.
3. Open its setup notebook and run all steps.
4. Build and push the container image to your Azure Container Registry.
5. Deploy the hosted agent version in your Foundry project.
6. Set the hosted agent ID in the infra notebook config and re-run deployment to provision APIM fronting for the Responses API.

### Clean up resources

Use the [clean-up-resources notebook](clean-up-resources.ipynb) to remove deployed resources when you are finished.
