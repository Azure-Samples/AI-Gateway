# Updating and Modifying Existing Azure AI Agents

This document explains how to update existing agents using the Azure AI Foundry SDK - including adding tools, modifying instructions, attaching knowledge bases (vector stores), and managing agent configurations.

---

## Table of Contents

1. [Overview](#1-overview)
2. [The update_agent Method](#2-the-update_agent-method)
3. [Listing and Retrieving Existing Agents](#3-listing-and-retrieving-existing-agents)
4. [Adding Tools to an Existing Agent](#4-adding-tools-to-an-existing-agent)
5. [Adding a Knowledge Base (Vector Store)](#5-adding-a-knowledge-base-vector-store)
6. [Modifying Agent Instructions and Settings](#6-modifying-agent-instructions-and-settings)
7. [Removing Tools or Resources](#7-removing-tools-or-resources)
8. [Complete Example: Full Agent Modification Workflow](#8-complete-example-full-agent-modification-workflow)

---

## 1. Overview

Unlike the `create_agent` method used in the lab notebooks, the Azure AI Foundry SDK also provides an `update_agent` method that allows you to modify an existing agent without recreating it. This is useful for:

- **Adding new tools** to extend agent capabilities
- **Attaching knowledge bases** (vector stores) for file search
- **Updating instructions** to change behavior
- **Adjusting model parameters** like temperature
- **Adding or updating metadata**

### Key Concept: Agents are Persistent

When you create an agent, it persists in your AI Foundry project until deleted. The ID returned from `create_agent` can be stored and used later to:
- Retrieve the agent with `get_agent`
- Modify it with `update_agent`
- Delete it with `delete_agent`

---

## 2. The update_agent Method

### Method Signature

```python
update_agent(
    agent_id: str,                              # Required: The ID of the agent to modify
    *,
    model: str | None = None,                   # Change the model deployment
    name: str | None = None,                    # Change the agent's name
    description: str | None = None,             # Change the description
    instructions: str | None = None,            # Change system instructions
    tools: List[ToolDefinition] | None = None,  # Replace/update tools
    tool_resources: ToolResources | None = None, # Update tool resources (e.g., vector stores)
    temperature: float | None = None,           # Adjust creativity (0-2)
    top_p: float | None = None,                 # Nucleus sampling parameter
    response_format: AgentsResponseFormatOption | None = None,  # Output format
    metadata: Dict[str, str] | None = None,     # Key/value metadata
    **kwargs
) -> Agent
```

### Important Notes

- **Only pass parameters you want to change** - omitted parameters keep their current values
- **Tools are replaced, not merged** - if you update tools, you must include ALL tools the agent should have
- **Tool resources follow the same pattern** - include all vector stores when updating

---

## 3. Listing and Retrieving Existing Agents

### List All Agents

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

project_client = AIProjectClient(
    endpoint=foundry_project_endpoint,
    credential=DefaultAzureCredential()
)

with project_client:
    agents_client = project_client.agents
    
    # List all agents in the project
    agents = agents_client.list_agents()
    
    for agent in agents.data:
        print(f"Agent ID: {agent.id}")
        print(f"  Name: {agent.name}")
        print(f"  Model: {agent.model}")
        print(f"  Instructions: {agent.instructions[:50]}...")
        print(f"  Tools: {[t['type'] for t in agent.tools]}")
        print()
```

### Retrieve a Specific Agent

```python
# Using agent ID stored from creation
agent_id = "asst_abc123xyz"

with project_client:
    agents_client = project_client.agents
    
    # Get the agent by ID
    agent = agents_client.get_agent(agent_id=agent_id)
    
    print(f"Retrieved agent: {agent.name}")
    print(f"Current instructions: {agent.instructions}")
    print(f"Current tools: {agent.tools}")
    print(f"Current tool_resources: {agent.tool_resources}")
```

---

## 4. Adding Tools to an Existing Agent

### Example: Add Bing Grounding to an Existing Agent

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.agents.models import BingGroundingTool

project_client = AIProjectClient(
    endpoint=foundry_project_endpoint,
    credential=DefaultAzureCredential()
)

# Assume we have an existing agent
existing_agent_id = "asst_abc123xyz"

with project_client:
    agents_client = project_client.agents
    
    # First, retrieve the existing agent to see current tools
    agent = agents_client.get_agent(agent_id=existing_agent_id)
    current_tools = agent.tools or []
    
    print(f"Current tools: {current_tools}")
    
    # Get Bing connection
    bing_connection = project_client.connections.get(name='bingSearch-connection')
    
    # Create Bing tool
    bing = BingGroundingTool(connection_id=bing_connection.id)
    
    # Combine existing tools with new tool
    # Note: bing.definitions returns a list of tool definitions
    combined_tools = current_tools + bing.definitions
    
    # Update the agent with combined tools
    updated_agent = agents_client.update_agent(
        agent_id=existing_agent_id,
        tools=combined_tools
    )
    
    print(f"Updated agent tools: {[t['type'] for t in updated_agent.tools]}")
```

### Example: Add OpenAPI Tool to an Existing Agent

```python
import jsonref
from azure.ai.agents.models import (
    OpenApiTool, 
    OpenApiConnectionAuthDetails, 
    OpenApiConnectionSecurityScheme
)

with project_client:
    agents_client = project_client.agents
    
    # Get existing agent
    agent = agents_client.get_agent(agent_id=existing_agent_id)
    current_tools = agent.tools or []
    
    # Load OpenAPI spec
    with open("./weather-openapi.json", "r") as f:
        openapi_spec = jsonref.loads(f.read())
    
    # Create OpenAPI tool
    weather_tool = OpenApiTool(
        name="get_weather",
        spec=openapi_spec,
        description="Retrieve weather information",
        auth=OpenApiConnectionAuthDetails(
            security_scheme=OpenApiConnectionSecurityScheme(
                connection_id=weather_api_connection_id
            )
        )
    )
    
    # Combine with existing tools
    combined_tools = current_tools + weather_tool.definitions
    
    # Update agent
    updated_agent = agents_client.update_agent(
        agent_id=existing_agent_id,
        tools=combined_tools
    )
    
    print(f"Agent now has {len(updated_agent.tools)} tools")
```

---

## 5. Adding a Knowledge Base (Vector Store)

### Step 1: Upload Files and Create Vector Store

```python
from azure.ai.agents.models import FilePurpose, FileSearchTool

with project_client:
    agents_client = project_client.agents
    
    # Upload a file
    file = agents_client.files.upload_and_poll(
        file_path="./product_documentation.md",
        purpose=FilePurpose.AGENTS
    )
    print(f"Uploaded file, ID: {file.id}")
    
    # Create vector store with the file
    vector_store = agents_client.vector_stores.create_and_poll(
        file_ids=[file.id],
        name="product_knowledge_base"
    )
    print(f"Created vector store, ID: {vector_store.id}")
```

### Step 2: Add File Search Tool to Existing Agent

```python
with project_client:
    agents_client = project_client.agents
    
    # Get existing agent
    agent = agents_client.get_agent(agent_id=existing_agent_id)
    current_tools = agent.tools or []
    current_tool_resources = agent.tool_resources or {}
    
    # Create file search tool
    file_search = FileSearchTool(vector_store_ids=[vector_store.id])
    
    # Combine tools
    combined_tools = current_tools + file_search.definitions
    
    # Merge tool_resources (file_search.resources contains vector store references)
    # file_search.resources typically looks like: {"file_search": {"vector_store_ids": [...]}}
    merged_resources = {**current_tool_resources, **file_search.resources}
    
    # Update the agent
    updated_agent = agents_client.update_agent(
        agent_id=existing_agent_id,
        tools=combined_tools,
        tool_resources=merged_resources
    )
    
    print(f"Agent updated with file search capability")
    print(f"Tool resources: {updated_agent.tool_resources}")
```

### Adding Files to an Existing Vector Store

If you already have a vector store attached to an agent and want to add more files:

```python
with project_client:
    agents_client = project_client.agents
    
    # Upload additional file
    new_file = agents_client.files.upload_and_poll(
        file_path="./additional_docs.pdf",
        purpose=FilePurpose.AGENTS
    )
    
    # Add file to existing vector store using batch
    file_batch = agents_client.vector_store_file_batches.create_and_poll(
        vector_store_id=existing_vector_store_id,
        file_ids=[new_file.id]
    )
    
    print(f"Added file to vector store: {file_batch.id}")
    # No agent update needed - the vector store is already attached!
```

---

## 6. Modifying Agent Instructions and Settings

### Update Instructions

```python
with project_client:
    agents_client = project_client.agents
    
    # Update only the instructions
    updated_agent = agents_client.update_agent(
        agent_id=existing_agent_id,
        instructions="""You are an expert customer support agent. 
        Always be polite and professional.
        Use the knowledge base to answer product questions.
        If you don't know the answer, say so honestly."""
    )
    
    print(f"Updated instructions: {updated_agent.instructions}")
```

### Update Temperature and Sampling

```python
with project_client:
    agents_client = project_client.agents
    
    # Make the agent more creative
    updated_agent = agents_client.update_agent(
        agent_id=existing_agent_id,
        temperature=0.8,  # Higher = more creative (default is often 1.0)
        top_p=0.95        # Nucleus sampling
    )
    
    print(f"Updated temperature: {updated_agent.temperature}")
```

### Update Name and Description

```python
with project_client:
    agents_client = project_client.agents
    
    updated_agent = agents_client.update_agent(
        agent_id=existing_agent_id,
        name="customer-support-agent-v2",
        description="Enhanced customer support agent with knowledge base access"
    )
    
    print(f"Updated name: {updated_agent.name}")
```

### Update Metadata

```python
with project_client:
    agents_client = project_client.agents
    
    # Add tracking metadata
    updated_agent = agents_client.update_agent(
        agent_id=existing_agent_id,
        metadata={
            "version": "2.0",
            "last_updated": "2026-02-11",
            "owner": "support-team",
            "environment": "production"
        }
    )
    
    print(f"Updated metadata: {updated_agent.metadata}")
```

---

## 7. Removing Tools or Resources

### Remove a Specific Tool

Since tools are replaced entirely, you need to filter out the tool you want to remove:

```python
with project_client:
    agents_client = project_client.agents
    
    # Get current agent
    agent = agents_client.get_agent(agent_id=existing_agent_id)
    current_tools = agent.tools or []
    
    # Filter out the tool you want to remove (e.g., remove Bing grounding)
    tools_without_bing = [
        tool for tool in current_tools 
        if tool.get('type') != 'bing_grounding'
    ]
    
    # Update agent with remaining tools
    updated_agent = agents_client.update_agent(
        agent_id=existing_agent_id,
        tools=tools_without_bing
    )
    
    print(f"Agent now has {len(updated_agent.tools)} tools")
```

### Remove a Vector Store from File Search

```python
from azure.ai.agents.models import FileSearchTool

with project_client:
    agents_client = project_client.agents
    
    # Get current agent
    agent = agents_client.get_agent(agent_id=existing_agent_id)
    
    # Get current vector store IDs
    current_vector_stores = agent.tool_resources.get('file_search', {}).get('vector_store_ids', [])
    
    # Remove the specific vector store
    vector_store_to_remove = "vs_abc123"
    updated_vector_stores = [vs for vs in current_vector_stores if vs != vector_store_to_remove]
    
    # Create new file search tool with remaining vector stores
    file_search = FileSearchTool(vector_store_ids=updated_vector_stores)
    
    # Filter tools to update file_search definition
    other_tools = [t for t in agent.tools if t.get('type') != 'file_search']
    combined_tools = other_tools + file_search.definitions
    
    # Update agent
    updated_agent = agents_client.update_agent(
        agent_id=existing_agent_id,
        tools=combined_tools,
        tool_resources=file_search.resources
    )
    
    print(f"Removed vector store from agent")
```

### Using Helper Methods (if available in FileSearchTool)

Some SDK versions include helper methods:

```python
# Add vector store to file search tool
file_search_tool.add_vector_store(new_vector_store.id)

# Remove vector store from file search tool  
file_search_tool.remove_vector_store(vector_store_to_remove_id)

# Then update the agent
agents_client.update_agent(
    agent_id=agent.id,
    tools=file_search_tool.definitions,
    tool_resources=file_search_tool.resources
)
```

---

## 8. Complete Example: Full Agent Modification Workflow

Here's a complete example that demonstrates the full workflow of creating an agent, then later updating it:

```python
import os
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.agents.models import (
    BingGroundingTool,
    FileSearchTool,
    FilePurpose
)

# Initialize client
project_client = AIProjectClient(
    endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
    credential=DefaultAzureCredential()
)

with project_client:
    agents_client = project_client.agents
    
    # ========================================
    # PHASE 1: Create a basic agent
    # ========================================
    
    print("=== Phase 1: Creating basic agent ===")
    
    agent = agents_client.create_agent(
        model=os.environ["MODEL_DEPLOYMENT_NAME"],
        name="my-support-agent",
        instructions="You are a helpful support agent."
    )
    print(f"Created agent: {agent.id}")
    
    # Store the agent ID (in real scenario, persist this)
    agent_id = agent.id
    
    # ========================================
    # PHASE 2: Later, add Bing grounding
    # ========================================
    
    print("\n=== Phase 2: Adding Bing grounding ===")
    
    # Retrieve the agent
    agent = agents_client.get_agent(agent_id=agent_id)
    
    # Get Bing connection and create tool
    bing_connection = project_client.connections.get(name='bingSearch-connection')
    bing_tool = BingGroundingTool(connection_id=bing_connection.id)
    
    # Update with Bing tool
    agent = agents_client.update_agent(
        agent_id=agent_id,
        tools=bing_tool.definitions,
        instructions="You are a helpful support agent. Use Bing to search for current information when needed."
    )
    print(f"Added Bing grounding. Tools: {[t['type'] for t in agent.tools]}")
    
    # ========================================
    # PHASE 3: Add a knowledge base
    # ========================================
    
    print("\n=== Phase 3: Adding knowledge base ===")
    
    # Upload documentation file
    file = agents_client.files.upload_and_poll(
        file_path="./product_docs.md",
        purpose=FilePurpose.AGENTS
    )
    print(f"Uploaded file: {file.id}")
    
    # Create vector store
    vector_store = agents_client.vector_stores.create_and_poll(
        file_ids=[file.id],
        name="product-knowledge-base"
    )
    print(f"Created vector store: {vector_store.id}")
    
    # Create file search tool
    file_search = FileSearchTool(vector_store_ids=[vector_store.id])
    
    # Combine with existing tools
    agent = agents_client.get_agent(agent_id=agent_id)
    combined_tools = agent.tools + file_search.definitions
    
    # Update agent
    agent = agents_client.update_agent(
        agent_id=agent_id,
        tools=combined_tools,
        tool_resources=file_search.resources,
        instructions="""You are a helpful support agent with access to:
        1. Bing search for current information
        2. Product documentation knowledge base
        
        Always check the knowledge base first for product questions.
        Use Bing for current events or information not in the knowledge base."""
    )
    print(f"Added file search. Tools: {[t['type'] for t in agent.tools]}")
    
    # ========================================
    # PHASE 4: Test the updated agent
    # ========================================
    
    print("\n=== Phase 4: Testing updated agent ===")
    
    thread = agents_client.threads.create()
    message = agents_client.messages.create(
        thread_id=thread.id,
        role="user",
        content="What features does our product have?"
    )
    
    run = agents_client.runs.create_and_process(
        thread_id=thread.id,
        agent_id=agent_id
    )
    
    print(f"Run status: {run.status}")
    
    if run.status == "completed":
        messages = agents_client.messages.list(thread_id=thread.id)
        for msg in messages:
            if msg.role == "assistant" and msg.text_messages:
                print(f"Agent response: {msg.text_messages[-1].text.value[:200]}...")
    
    # ========================================
    # PHASE 5: Cleanup (optional)
    # ========================================
    
    print("\n=== Phase 5: Cleanup ===")
    
    # To keep the agent for later use, skip deletion
    # agents_client.delete_agent(agent_id)
    # agents_client.vector_stores.delete(vector_store.id)
    # agents_client.files.delete(file.id)
    
    print(f"Agent {agent_id} is ready for production use!")
```

---

## Summary

### Key Patterns for Updating Agents

| Task | Pattern |
|------|---------|
| Add tool | Get current tools → Combine with new → `update_agent(tools=combined)` |
| Add knowledge base | Create vector store → Create FileSearchTool → `update_agent(tools=..., tool_resources=...)` |
| Update instructions | `update_agent(instructions="...")` |
| Change model params | `update_agent(temperature=..., top_p=...)` |
| Remove tool | Filter out tool from list → `update_agent(tools=filtered)` |

### Best Practices

1. **Always retrieve before updating** - Get current agent state to avoid losing existing configuration
2. **Merge tools carefully** - Tools are replaced, not merged automatically
3. **Test after updates** - Run a test conversation to verify changes work correctly
4. **Use metadata** - Track versions and changes in the metadata field
5. **Store agent IDs** - Persist agent IDs for later retrieval and updates

### Required Packages

```bash
pip install azure-ai-projects azure-ai-agents azure-identity
```

---

## Additional Resources

- [AgentsClient API Reference](https://learn.microsoft.com/python/api/azure-ai-agents/azure.ai.agents.agentsclient)
- [File Search Tool Documentation](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/file-search)
- [Azure AI Agents SDK Overview](https://learn.microsoft.com/python/api/overview/azure/ai-agents-readme)
