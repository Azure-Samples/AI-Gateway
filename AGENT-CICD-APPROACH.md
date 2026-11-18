# CI/CD Approach for Azure AI Agent Deployments

This document outlines a production-ready approach for deploying Azure AI Foundry agents across environments using a declarative, manifest-based pattern.

---

## Table of Contents

1. [The Problem](#1-the-problem)
2. [Recommended Approach: Manifest-Based Deployment](#2-recommended-approach-manifest-based-deployment)
3. [Manifest Schema Design](#3-manifest-schema-design)
4. [Environment Configuration](#4-environment-configuration)
5. [Deployment CLI Tool](#5-deployment-cli-tool)
6. [CI/CD Pipeline Structure](#6-cicd-pipeline-structure)
7. [Testing Strategy](#7-testing-strategy)
8. [Key Design Decisions](#8-key-design-decisions)
9. [Infrastructure vs Application Layer](#9-infrastructure-vs-application-layer)
10. [Alternative Approaches Considered](#10-alternative-approaches-considered)
11. [Implementation Roadmap](#11-implementation-roadmap)

---

## 1. The Problem

Running Python SDK scripts directly in CI/CD pipelines has several issues:

| Issue | Description |
|-------|-------------|
| **Not Declarative** | Imperative scripts are harder to review, diff, and reason about in pull requests |
| **Environment Coupling** | Connection IDs, endpoints, and secrets differ per environment and are hardcoded |
| **No Idempotency Guarantee** | Running twice might create duplicate agents or fail unexpectedly |
| **Drift Detection** | No way to know if someone manually changed the agent in the Azure portal |
| **Poor Auditability** | Changes to agent behavior aren't easily tracked in version control |

### Current State (Lab Notebooks)

```python
# This pattern works for experimentation but not production
agent = project_client.agents.create_agent(
    model="gpt-4o",
    name="my-agent",
    instructions="...",
    tools=[...]
)
```

**Problems:**
- Hardcoded values
- No environment awareness
- Creates new agent every run
- No state management

---

## 2. Recommended Approach: Manifest-Based Deployment

Adopt a **declarative manifest approach** similar to Kubernetes, Terraform, or Azure Bicep patterns:

### Core Principles

1. **Declarative** - Define the desired end state, not the steps to get there
2. **Idempotent** - Running the same deployment multiple times yields the same result
3. **Environment-Agnostic** - Same manifests work across dev/staging/prod with variable substitution
4. **Version Controlled** - All agent configurations live in Git
5. **Reviewable** - Changes are visible in pull request diffs

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Source Control (Git)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   agents/    │  │environments/ │  │   knowledge/         │  │
│  │  *.yaml      │  │  dev.yaml    │  │   product_docs.md    │  │
│  │              │  │  staging.yaml│  │   faq.md             │  │
│  │              │  │  prod.yaml   │  │                      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Deployment CLI Tool                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Load manifests + environment config                  │  │
│  │  2. Resolve variable substitutions                       │  │
│  │  3. Query current state (get_agent)                      │  │
│  │  4. Calculate diff (create vs update vs no-op)           │  │
│  │  5. Apply changes (create_agent / update_agent)          │  │
│  │  6. Upload files to vector stores if needed              │  │
│  │  7. Output deployment report                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Azure AI Foundry Project                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │    Agents    │  │Vector Stores │  │    Connections       │  │
│  │              │  │              │  │    (Bing, APIs)      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Manifest Schema Design

### Agent Manifest Structure

```yaml
# agents/customer-support-agent.yaml
apiVersion: agents/v1
kind: Agent
metadata:
  name: customer-support-agent
  description: "Production customer support agent with knowledge base access"
  labels:
    team: support
    tier: production
spec:
  # Model configuration
  model: ${MODEL_DEPLOYMENT_NAME}
  
  # Agent behavior
  instructions: |
    You are a helpful customer support agent for Contoso Products.
    
    Guidelines:
    - Always check the product knowledge base first for product questions
    - Use Bing search for current information, pricing, or news
    - Be polite, professional, and concise
    - If you don't know the answer, say so honestly
    
  # Model parameters
  temperature: 0.7
  topP: 0.95
  
  # Tools configuration
  tools:
    - type: bing_grounding
      config:
        connectionRef: ${BING_CONNECTION_NAME}
    
    - type: file_search
      config:
        vectorStoreRef: product-knowledge-base
    
    - type: openapi
      config:
        name: weather_api
        specPath: ./openapi/weather-openapi.json
        connectionRef: ${WEATHER_API_CONNECTION_NAME}
        description: "Get weather information for locations"
  
  # Tool resources (vector stores)
  toolResources:
    vectorStores:
      - name: product-knowledge-base
        files:
          - path: ./knowledge/product_catalog.md
          - path: ./knowledge/faq.md
          - path: ./knowledge/troubleshooting_guide.md
        # Or reference existing blob storage
        # blobUri: ${KNOWLEDGE_BASE_BLOB_URI}
  
  # Metadata for tracking
  metadata:
    version: "2.1.0"
    owner: "support-team@contoso.com"
    lastReviewedBy: "jane.doe@contoso.com"
```

### Multi-Agent Deployment

```yaml
# agents/sales-team/order-agent.yaml
apiVersion: agents/v1
kind: Agent
metadata:
  name: order-processing-agent
  namespace: sales  # Logical grouping
spec:
  model: ${MODEL_DEPLOYMENT_NAME}
  instructions: |
    You are a sales assistant that helps process orders.
  tools:
    - type: openapi
      config:
        name: product_catalog
        specPath: ./openapi/catalog-openapi.json
        connectionRef: ${CATALOG_API_CONNECTION}
    - type: openapi
      config:
        name: place_order
        specPath: ./openapi/order-openapi.json
        connectionRef: ${ORDER_API_CONNECTION}
```

### Manifest Validation Schema

```yaml
# schemas/agent-manifest-schema.yaml (JSON Schema for validation)
$schema: "http://json-schema.org/draft-07/schema#"
type: object
required:
  - apiVersion
  - kind
  - metadata
  - spec
properties:
  apiVersion:
    type: string
    enum: ["agents/v1"]
  kind:
    type: string
    enum: ["Agent"]
  metadata:
    type: object
    required: ["name"]
    properties:
      name:
        type: string
        pattern: "^[a-z0-9-]+$"
      description:
        type: string
      labels:
        type: object
  spec:
    type: object
    required: ["model", "instructions"]
    properties:
      model:
        type: string
      instructions:
        type: string
      temperature:
        type: number
        minimum: 0
        maximum: 2
      tools:
        type: array
        items:
          type: object
          required: ["type"]
```

---

## 4. Environment Configuration

### Environment Overlay Files

```yaml
# environments/dev.yaml
ENVIRONMENT: dev
FOUNDRY_ENDPOINT: https://dev-aiproject.services.ai.azure.com
MODEL_DEPLOYMENT_NAME: gpt-4o-dev
BING_CONNECTION_NAME: bing-search-dev
WEATHER_API_CONNECTION_NAME: weather-api-dev
CATALOG_API_CONNECTION: catalog-api-dev
ORDER_API_CONNECTION: order-api-dev

# Optional: Override specific agent settings for dev
agentOverrides:
  customer-support-agent:
    spec:
      temperature: 1.0  # More creative in dev for testing
```

```yaml
# environments/staging.yaml
ENVIRONMENT: staging
FOUNDRY_ENDPOINT: https://staging-aiproject.services.ai.azure.com
MODEL_DEPLOYMENT_NAME: gpt-4o-staging
BING_CONNECTION_NAME: bing-search-staging
WEATHER_API_CONNECTION_NAME: weather-api-staging
CATALOG_API_CONNECTION: catalog-api-staging
ORDER_API_CONNECTION: order-api-staging
```

```yaml
# environments/prod.yaml
ENVIRONMENT: prod
FOUNDRY_ENDPOINT: https://prod-aiproject.services.ai.azure.com
MODEL_DEPLOYMENT_NAME: gpt-4o-prod
BING_CONNECTION_NAME: bing-search-prod
WEATHER_API_CONNECTION_NAME: weather-api-prod
CATALOG_API_CONNECTION: catalog-api-prod
ORDER_API_CONNECTION: order-api-prod

# Production-specific settings
agentOverrides:
  customer-support-agent:
    spec:
      temperature: 0.5  # More deterministic in production
```

### Secrets Management

Secrets should NOT be in environment files. Instead:

```yaml
# environments/prod.yaml
# Reference Azure Key Vault or environment variables
FOUNDRY_ENDPOINT: ${AZURE_FOUNDRY_ENDPOINT}  # From Key Vault / CI variable
```

---

## 5. Deployment CLI Tool

### Proposed CLI Interface

```bash
# Validate manifests against schema
agent-deploy validate -f agents/

# Show what would change (dry run)
agent-deploy plan -f agents/ -e environments/prod.yaml

# Apply changes
agent-deploy apply -f agents/ -e environments/prod.yaml

# Show diff between desired and actual state
agent-deploy diff -f agents/ -e environments/prod.yaml

# Get status of deployed agents
agent-deploy status -e environments/prod.yaml

# Delete an agent
agent-deploy delete -n customer-support-agent -e environments/prod.yaml

# Export current agent state to manifest (reverse engineering)
agent-deploy export -n customer-support-agent -e environments/prod.yaml > exported-agent.yaml
```

### CLI Output Example

```
$ agent-deploy plan -f agents/ -e environments/prod.yaml

Planning deployment to: https://prod-aiproject.services.ai.azure.com
Environment: prod

Resolving manifests...
  ✓ agents/customer-support-agent.yaml
  ✓ agents/sales-team/order-agent.yaml

Comparing desired state vs actual state...

customer-support-agent:
  ~ instructions: (modified - 3 lines changed)
  + tools[2]: openapi/weather_api (new tool)
  ~ temperature: 0.7 → 0.5

order-processing-agent:
  (no changes)

Plan: 1 to update, 0 to create, 1 unchanged

Run `agent-deploy apply` to execute this plan.
```

### Core Implementation Logic (Pseudocode)

```python
class AgentDeployer:
    def __init__(self, endpoint: str, credential):
        self.client = AIProjectClient(endpoint=endpoint, credential=credential)
    
    def plan(self, manifests: List[AgentManifest], env: EnvironmentConfig) -> DeploymentPlan:
        plan = DeploymentPlan()
        
        for manifest in manifests:
            resolved = self._resolve_variables(manifest, env)
            agent_name = resolved.metadata.name
            
            # Check if agent exists
            existing = self._get_agent_by_name(agent_name)
            
            if existing is None:
                plan.add_create(resolved)
            elif self._has_changes(existing, resolved):
                plan.add_update(existing.id, resolved, self._calculate_diff(existing, resolved))
            else:
                plan.add_unchanged(agent_name)
        
        return plan
    
    def apply(self, plan: DeploymentPlan) -> DeploymentResult:
        results = []
        
        for action in plan.actions:
            if action.type == "create":
                result = self._create_agent(action.manifest)
            elif action.type == "update":
                result = self._update_agent(action.agent_id, action.manifest)
            results.append(result)
        
        return DeploymentResult(results)
    
    def _get_agent_by_name(self, name: str) -> Optional[Agent]:
        """Look up agent by name (idempotency key)"""
        agents = self.client.agents.list_agents()
        for agent in agents.data:
            if agent.name == name:
                return agent
        return None
```

---

## 6. CI/CD Pipeline Structure

### GitHub Actions Example

```yaml
# .github/workflows/deploy-agents.yaml
name: Deploy AI Agents

on:
  push:
    branches: [main]
    paths:
      - 'agents/**'
      - 'knowledge/**'
      - 'environments/**'
  pull_request:
    branches: [main]
    paths:
      - 'agents/**'
      - 'knowledge/**'
      - 'environments/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      
      - name: Install agent-deploy CLI
        run: pip install agent-deploy-cli
      
      - name: Validate manifests
        run: agent-deploy validate -f agents/

  plan-dev:
    needs: validate
    runs-on: ubuntu-latest
    environment: development
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS_DEV }}
      
      - name: Plan deployment
        run: |
          agent-deploy plan -f agents/ -e environments/dev.yaml
        env:
          AZURE_FOUNDRY_ENDPOINT: ${{ secrets.FOUNDRY_ENDPOINT_DEV }}

  deploy-dev:
    needs: plan-dev
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: development
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS_DEV }}
      
      - name: Deploy to dev
        run: |
          agent-deploy apply -f agents/ -e environments/dev.yaml
        env:
          AZURE_FOUNDRY_ENDPOINT: ${{ secrets.FOUNDRY_ENDPOINT_DEV }}
      
      - name: Run smoke tests
        run: |
          python tests/smoke_test.py --env dev

  deploy-staging:
    needs: deploy-dev
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS_STAGING }}
      
      - name: Deploy to staging
        run: |
          agent-deploy apply -f agents/ -e environments/staging.yaml
      
      - name: Run integration tests
        run: |
          python tests/integration_test.py --env staging

  deploy-prod:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: 
      name: production
      # Manual approval required
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS_PROD }}
      
      - name: Deploy to production
        run: |
          agent-deploy apply -f agents/ -e environments/prod.yaml
      
      - name: Smoke test
        run: |
          python tests/smoke_test.py --env prod
      
      - name: Tag release
        run: |
          git tag "agents-$(date +%Y%m%d-%H%M%S)"
          git push --tags
```

### Pipeline Flow Diagram

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   PR Created    │────▶│   Validate +    │────▶│   PR Merged     │
│                 │     │   Plan (dev)    │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Production    │◀────│   Staging       │◀────│   Development   │
│   (manual gate) │     │   + Int Tests   │     │   + Smoke Tests │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ AI Foundry Prod │     │AI Foundry Stage │     │ AI Foundry Dev  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## 7. Testing Strategy

### Test Levels

| Level | When | What |
|-------|------|------|
| **Schema Validation** | PR / Pre-deploy | Manifest structure is valid |
| **Dry Run** | PR / Pre-deploy | Plan shows expected changes |
| **Smoke Tests** | Post-deploy | Agent responds to basic prompts |
| **Integration Tests** | Post-deploy (staging) | Tools work correctly, end-to-end flows |
| **Evaluation Tests** | Scheduled / Release | Quality metrics (groundedness, coherence, etc.) |

### Smoke Test Example

```python
# tests/smoke_test.py
import os
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

def test_agent_responds(agent_name: str, endpoint: str):
    """Verify agent can receive a message and respond"""
    client = AIProjectClient(endpoint=endpoint, credential=DefaultAzureCredential())
    
    # Find agent by name
    agents = client.agents.list_agents()
    agent = next((a for a in agents.data if a.name == agent_name), None)
    assert agent is not None, f"Agent {agent_name} not found"
    
    # Create thread and send test message
    thread = client.agents.threads.create()
    client.agents.messages.create(
        thread_id=thread.id,
        role="user",
        content="Hello, are you working?"
    )
    
    run = client.agents.runs.create_and_process(
        thread_id=thread.id,
        agent_id=agent.id
    )
    
    assert run.status == "completed", f"Run failed: {run.last_error}"
    
    messages = client.agents.messages.list(thread_id=thread.id)
    assistant_messages = [m for m in messages if m.role == "assistant"]
    assert len(assistant_messages) > 0, "No assistant response"
    
    print(f"✓ Agent {agent_name} smoke test passed")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", required=True)
    args = parser.parse_args()
    
    # Load environment config and run tests
    endpoint = os.environ["AZURE_FOUNDRY_ENDPOINT"]
    test_agent_responds("customer-support-agent", endpoint)
```

### Integration Test Example

```python
# tests/integration_test.py
def test_file_search_tool_works(agent_name: str, endpoint: str):
    """Verify agent can search uploaded knowledge base"""
    client = AIProjectClient(endpoint=endpoint, credential=DefaultAzureCredential())
    
    agent = get_agent_by_name(client, agent_name)
    thread = client.agents.threads.create()
    
    # Ask a question that requires knowledge base
    client.agents.messages.create(
        thread_id=thread.id,
        role="user",
        content="What is the return policy for Contoso products?"
    )
    
    run = client.agents.runs.create_and_process(
        thread_id=thread.id,
        agent_id=agent.id
    )
    
    assert run.status == "completed"
    
    # Verify file_search tool was used
    run_steps = client.agents.run_steps.list(thread_id=thread.id, run_id=run.id)
    tool_calls = [s for s in run_steps if s.type == "tool_calls"]
    file_search_calls = [
        tc for step in tool_calls 
        for tc in step.step_details.get("tool_calls", [])
        if tc.get("type") == "file_search"
    ]
    
    assert len(file_search_calls) > 0, "File search tool was not used"
    print(f"✓ File search integration test passed")
```

---

## 8. Key Design Decisions

### Idempotency Strategy: Name-Based Lookup

| Approach | Pros | Cons |
|----------|------|------|
| **Name-based lookup** ✅ | Simple, no state file, preserves agent ID | Need consistent naming |
| Version-based (v1, v2, v3) | Clear history, easy rollback | Accumulates old agents |
| ID tracking (state file) | Explicit, Terraform-like | Requires state management |

**Recommendation:** Use **name-based lookup with update** - the agent name serves as the idempotency key. The deployment tool looks up agents by name and creates or updates accordingly.

### What Gets Version Controlled

| Asset | Version Control? | Notes |
|-------|------------------|-------|
| Agent manifests (YAML) | ✅ Yes | Core configuration |
| Knowledge base files | ✅ Yes | Or reference external blob storage |
| Connection names (refs) | ✅ Yes | Actual connections created via IaC |
| OpenAPI specs | ✅ Yes | Define API tool interfaces |
| Agent IDs | ❌ No | Generated at runtime |
| API keys / secrets | ❌ No | From Key Vault / CI secrets |
| Vector store IDs | ❌ No | Created dynamically |

### Handling Vector Stores and Files

**Option A: Recreate on Deploy (Simple)**
```
Deploy → Upload files → Create new vector store → Attach to agent
```
- Simple but may cause brief inconsistency during deployment

**Option B: Incremental Updates (Complex)**
```
Deploy → Diff files → Upload only new/changed → Update vector store
```
- More efficient but requires content hashing and tracking

**Recommendation:** Start with Option A; optimize to Option B later if file uploads become slow.

---

## 9. Infrastructure vs Application Layer

Clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────┐
│         Infrastructure Layer (Bicep / Terraform)                │
│                                                                 │
│  Resources (deployed once, shared across agents):               │
│  • Azure AI Foundry Project (Hub + Project)                     │
│  • Azure API Management (APIM)                                  │
│  • Connections (Bing, OpenAPI endpoints, API keys)              │
│  • Azure Key Vault                                              │
│  • Storage Account (for knowledge base files)                   │
│  • Log Analytics Workspace                                      │
│  • Application Insights                                         │
│                                                                 │
│  Deployment: IaC pipelines (separate from agent deployment)     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ References (connection names, endpoints)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│         Application Layer (Manifest Deployment)                 │
│                                                                 │
│  Resources (deployed per agent, frequent changes):              │
│  • Agent definitions (name, instructions, model, tools)         │
│  • Vector stores                                                │
│  • Uploaded files (knowledge base content)                      │
│  • Tool configurations                                          │
│                                                                 │
│  Deployment: agent-deploy CLI (this approach)                   │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Separation?

- **Infrastructure changes are slow** - APIM can take 30+ minutes to deploy
- **Agent changes are fast** - Agent updates take seconds
- **Different change frequency** - Infrastructure is stable; agents evolve rapidly
- **Different approval processes** - Infrastructure may need CAB approval; agent instructions can be team-owned

---

## 10. Alternative Approaches Considered

| Approach | Why It Was Not Chosen |
|----------|----------------------|
| **Pure ARM/Bicep** | Agents aren't first-class ARM resources - would need custom deployment scripts anyway |
| **Terraform only** | Same limitation - no native azurerm_ai_agent resource |
| **SDK scripts per agent** | Not declarative, hard to review, environment handling is messy |
| **Portal-only** | No version control, no reproducibility, no CI/CD, no audit trail |
| **Azure DevOps Pipelines** | Works fine, but GitHub Actions example is more portable |

### What About Azure's Native Tooling?

As of this writing, Azure doesn't provide a first-class declarative deployment mechanism for AI Foundry agents. This approach fills that gap. If Microsoft releases an official tool (e.g., `az ai agent deploy`), this pattern could adapt to use it under the hood.

---

## 11. Implementation Roadmap

### Phase 1: MVP (1-2 weeks)

- [ ] Define final manifest schema (YAML)
- [ ] Build basic CLI with `validate`, `plan`, `apply` commands
- [ ] Implement name-based agent lookup (idempotency)
- [ ] Support basic tools: Bing, file_search, OpenAPI
- [ ] Environment variable substitution
- [ ] Basic smoke test framework

### Phase 2: Production Hardening (2-3 weeks)

- [ ] Add `diff` and `status` commands
- [ ] Implement `export` (reverse engineer existing agent to manifest)
- [ ] Add JSON Schema validation for manifests
- [ ] Detailed deployment logs and error handling
- [ ] Support for agent metadata and labels
- [ ] Vector store file diffing (only upload changed files)

### Phase 3: Advanced Features (3-4 weeks)

- [ ] Support for `agentOverrides` in environment files
- [ ] Rollback command (deploy previous Git commit's manifests)
- [ ] Agent versioning (maintain history within the tool)
- [ ] Integration with Azure AI Evaluation SDK for quality gates
- [ ] Support for namespace/folder organization
- [ ] Helm-like templating (optional)

### Phase 4: Ecosystem (Ongoing)

- [ ] GitHub Action: `agent-deploy-action`
- [ ] Azure DevOps Task
- [ ] VS Code extension for manifest authoring
- [ ] Documentation and examples

---

## What This Enables

| Capability | Benefit |
|------------|---------|
| **Code review for agent changes** | PR shows exactly what's changing in the manifest |
| **Audit trail** | Git history shows who changed what and when |
| **Rollback** | Revert to previous manifest and redeploy |
| **Environment parity** | Same manifest structure, different variable values |
| **Parallel development** | Multiple teams can own different agent manifests |
| **Compliance** | Track all agent changes for regulatory requirements |
| **Disaster recovery** | Rebuild entire agent fleet from manifests |

---

## Repository Structure Example

```
my-agents-repo/
├── .github/
│   └── workflows/
│       └── deploy-agents.yaml
├── agents/
│   ├── customer-support-agent.yaml
│   └── sales-team/
│       ├── order-agent.yaml
│       └── inventory-agent.yaml
├── environments/
│   ├── dev.yaml
│   ├── staging.yaml
│   └── prod.yaml
├── knowledge/
│   ├── product_catalog.md
│   ├── faq.md
│   └── troubleshooting_guide.md
├── openapi/
│   ├── weather-openapi.json
│   ├── catalog-openapi.json
│   └── order-openapi.json
├── tests/
│   ├── smoke_test.py
│   └── integration_test.py
├── schemas/
│   └── agent-manifest-schema.yaml
└── README.md
```

---

## Next Steps

1. **Review this approach** and provide feedback
2. **Decide on schema details** (finalize manifest format)
3. **Build MVP CLI** as a proof of concept
4. **Test with real agents** in a development environment
5. **Iterate based on learnings**

---

*Document created: February 2026*
*Last updated: February 2026*
