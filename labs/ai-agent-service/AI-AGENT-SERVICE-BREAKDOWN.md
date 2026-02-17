# Azure AI Agent Service Code Breakdown

This document provides a detailed breakdown of the Python code used in the AI Agent Service lab notebooks, explaining the Azure AI Foundry SDK syntax for building AI agents with tools.

---

## Table of Contents

1. [Lab Overview & Architecture](#1-lab-overview--architecture)
2. [Azure Resources Deployed](#2-azure-resources-deployed)
3. [SDK Initialization Patterns](#3-sdk-initialization-patterns)
4. [Creating and Running Agents](#4-creating-and-running-agents)
5. [Working with Tools](#5-working-with-tools)
6. [Bing Grounding Tool](#6-bing-grounding-tool)
7. [OpenAPI Tools](#7-openapi-tools)
8. [Thread and Message Management](#8-thread-and-message-management)
9. [Monitoring with Application Insights](#9-monitoring-with-application-insights)
10. [V1 vs V2 SDK Differences](#10-v1-vs-v2-sdk-differences)

---

## 1. Lab Overview & Architecture

This lab demonstrates how to build AI agents using the Azure AI Agent Service, integrated with Azure API Management (APIM) for:
- **Controlling AI model access** - Route requests through APIM
- **Integrating external services** - Bing Search, Logic Apps, custom APIs
- **Monitoring and observability** - Application Insights telemetry

### Lab Versions
- **V1 (ai-agent-service-v1.ipynb)**: Uses AI Foundry Hub & Projects architecture with connection strings
- **V2 (ai-agent-service-v2.ipynb)**: Uses newer AI Foundry endpoint-based architecture

---

## 2. Azure Resources Deployed

The Bicep templates deploy the following resources:

| Resource | Purpose |
|----------|---------|
| **Azure API Management** | Gateway for AI services and custom APIs |
| **Azure OpenAI / AI Services** | Language models (GPT-4o) |
| **AI Foundry Project** | Agent management and orchestration |
| **Bing Search** | Web search grounding for agents |
| **Logic Apps** | Order processing workflow |
| **Application Insights** | Telemetry and monitoring |
| **Log Analytics** | Centralized logging |

### Configuration Variables

```python
# V1 Configuration
openai_resources = [ {"name": "openai1", "location": "swedencentral"} ]
openai_model_name = "gpt-4o"
openai_model_version = "2024-08-06"
openai_model_sku = "GlobalStandard"
openai_model_capacity = 400
openai_deployment_name = "gpt-4o"
openai_api_version = "2025-01-01-preview"

# V2 Configuration 
aiservices_config = [{"name": "foundry1", "location": "eastus2"}]
models_config = [{"name": "gpt-4.1-mini", "publisher": "OpenAI", 
                  "version": "2025-04-14", "sku": "GlobalStandard", "capacity": 20}]
```

---

## 3. SDK Initialization Patterns

### Required Imports

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
```

### V1: Connection String Pattern

```python
# Install specific SDK version for V1
%pip install azure-ai-projects==1.0.0b10

project_client = AIProjectClient.from_connection_string(
    credential=DefaultAzureCredential(),
    conn_str=project_connection_string  # Format: "endpoint;subscription_id;resource_group;project_name"
)
```

### V2: Endpoint Pattern

```python
# Install specific SDK version for V2
%pip install azure-ai-projects==1.0.0b12

project_client = AIProjectClient(
    endpoint=foundry_project_endpoint,  # Direct endpoint URL
    credential=DefaultAzureCredential()
)
```

### Using Context Managers

Both patterns support context managers for automatic resource cleanup:

```python
with AIProjectClient(...) as project_client:
    # Client is automatically cleaned up when exiting the block
    agent = project_client.agents.create_agent(...)
```

---

## 4. Creating and Running Agents

### Agent Lifecycle

1. **Create Agent** - Define model, name, instructions, and tools
2. **Create Thread** - Conversation container
3. **Create Message** - User input
4. **Create Run** - Execute the agent
5. **Poll for Completion** - Wait for agent to finish
6. **Retrieve Messages** - Get agent's response
7. **Cleanup** - Delete agent when done

### Basic Agent Creation (V1)

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

prompt_content = "I need to solve the equation `3x + 11 = 14`. Can you help me?"

with AIProjectClient.from_connection_string(
    credential=DefaultAzureCredential(),
    conn_str=project_connection_string
) as project_client:
    
    # Step 1: Create the agent
    maths_agent = project_client.agents.create_agent(
        model=openai_deployment_name,  # e.g., "gpt-4o"
        name="math-tutor",
        instructions="You are a personal math tutor. Answer questions briefly, in a sentence or less."
    )
    print(f"Created agent, agent ID: {maths_agent.id}")

    # Step 2: Create a conversation thread
    thread = project_client.agents.create_thread()
    print(f"Created thread, thread ID: {thread.id}")

    # Step 3: Add user message to thread
    message = project_client.agents.create_message(
        thread_id=thread.id,
        role="user",
        content=prompt_content
    )
    print(f"Created message, message ID: {message.id}")

    # Step 4: Create and start the run
    run = project_client.agents.create_run(
        thread_id=thread.id,
        agent_id=maths_agent.id
    )

    # Step 5: Poll until completion
    while run.status in ["queued", "in_progress", "requires_action"]:
        time.sleep(1)
        run = project_client.agents.get_run(thread_id=thread.id, run_id=run.id)
        print(f"Run status: {run.status}")

    # Step 6: Retrieve messages
    messages = project_client.agents.list_messages(thread_id=thread.id)
    print(f"🗨️ {messages.data[0].content[0].text.value}")
```

### Basic Agent Creation (V2)

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.agents.models import CodeInterpreterTool

project_client = AIProjectClient(
    endpoint=foundry_project_endpoint,
    credential=DefaultAzureCredential()
)

code_interpreter = CodeInterpreterTool()

with project_client:
    # Create agent with code interpreter tool
    agent = project_client.agents.create_agent(
        model=str(models_config[0].get('name')),
        name="my-maths-agent",
        instructions="You are a personal math tutor. Answer questions briefly.",
        tools=code_interpreter.definitions  # Attach tools
    )
    
    # Create thread (note: different method path in V2)
    thread = project_client.agents.threads.create()
    
    # Create message (note: different method path in V2)
    message = project_client.agents.messages.create(
        thread_id=thread.id,
        role="user",
        content="I need to solve the equation `3x + 11 = 14`. Can you help me?"
    )
    
    # Create and process run automatically
    run = project_client.agents.runs.create_and_process(
        thread_id=thread.id,
        agent_id=agent.id
    )
    
    # Get messages
    messages = project_client.agents.messages.list(thread_id=thread.id)
    for message in messages:
        print(f"Role: {message.role}, Content: {message.content}")
    
    # Cleanup
    project_client.agents.delete_agent(agent.id)
```

### Run Processing Options

| Method | Description |
|--------|-------------|
| `create_run()` | Start run, requires manual polling |
| `create_and_process_run()` (V1) | Auto-processes until completion |
| `runs.create_and_process()` (V2) | Auto-processes until completion |

---

## 5. Working with Tools

Tools extend agent capabilities. The SDK supports several built-in tools:

| Tool Type | Import | Purpose |
|-----------|--------|---------|
| `CodeInterpreterTool` | `azure.ai.agents.models` | Execute Python code |
| `BingGroundingTool` | `azure.ai.projects.models` (V1) / `azure.ai.agents.models` (V2) | Web search |
| `OpenApiTool` | `azure.ai.projects.models` (V1) / `azure.ai.agents.models` (V2) | Call REST APIs |

### Tool Attachment Pattern

```python
# Tools are defined and passed during agent creation
agent = project_client.agents.create_agent(
    model="gpt-4o",
    name="my-agent",
    instructions="...",
    tools=my_tool.definitions  # List of tool definitions
)
```

---

## 6. Bing Grounding Tool

The Bing Grounding Tool enables agents to search the web for current information.

### V1 Pattern

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.projects.models import BingGroundingTool

project_client = AIProjectClient.from_connection_string(
    credential=DefaultAzureCredential(),
    conn_str=project_connection_string
)

# Get Bing connection from AI Foundry
bing_connection = project_client.connections.get(connection_name=bing_search_connection)
conn_id = bing_connection.id

# Initialize Bing tool with connection ID
bing = BingGroundingTool(connection_id=conn_id)

with project_client:
    # Create agent with Bing tool
    bing_agent = project_client.agents.create_agent(
        model=openai_deployment_name,
        name="my-bing-assistant",
        instructions="You are a helpful assistant",
        tools=bing.definitions,
        headers={"x-ms-enable-preview": "true"}  # Required for preview features
    )
    
    thread = project_client.agents.create_thread()
    
    message = project_client.agents.create_message(
        thread_id=thread.id,
        role="user",
        content="What are the top news today?"
    )
    
    # Auto-process handles tool calls internally
    run = project_client.agents.create_and_process_run(
        thread_id=thread.id,
        agent_id=bing_agent.id
    )
    
    messages = project_client.agents.list_messages(thread_id=thread.id)
    print(f"🗨️ {messages.data[0].content[0].text.value}")
```

### V2 Pattern

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.agents.models import BingGroundingTool, ListSortOrder, MessageTextContent

project_client = AIProjectClient(
    endpoint=foundry_project_endpoint,
    credential=DefaultAzureCredential()
)
agents_client = project_client.agents

# Get connection by name
bing_connection = project_client.connections.get(name='bingSearch-connection')
conn_id = bing_connection.id

bing = BingGroundingTool(connection_id=conn_id)

with project_client:
    bing_agent = agents_client.create_agent(
        model=str(models_config[0].get('name')),
        name="my-bing-assistant",
        instructions="You are a helpful assistant who uses Bing Search to answer questions.",
        tools=bing.definitions,
        headers={"x-ms-enable-preview": "true"}
    )
    
    thread = agents_client.threads.create()
    
    message = agents_client.messages.create(
        thread_id=thread.id,
        role="user",
        content="What are the top 5 news headlines today from the UK?"
    )
    
    # Create run and poll manually
    run = agents_client.runs.create(thread_id=thread.id, agent_id=bing_agent.id)
    
    while run.status in ["queued", "in_progress", "requires_action"]:
        run = agents_client.runs.get(thread_id=thread.id, run_id=run.id)
        print(f"⏳ Run status: {run.status}")
    
    # Fetch messages with ordering
    messages = agents_client.messages.list(
        thread_id=thread.id,
        order=ListSortOrder.ASCENDING
    )
    
    for item in messages:
        last_message_content = item.content[-1]
        if isinstance(last_message_content, MessageTextContent):
            print(f"🗨️ {item.role}: {last_message_content.text.value}")
    
    agents_client.delete_agent(bing_agent.id)
```

---

## 7. OpenAPI Tools

OpenAPI tools allow agents to call REST APIs defined by OpenAPI specifications.

### Required Imports

```python
import jsonref  # For resolving JSON references in OpenAPI specs
from azure.ai.projects.models import (  # V1
    OpenApiTool,
    OpenApiConnectionAuthDetails,
    OpenApiConnectionSecurityScheme
)
# Or for V2:
from azure.ai.agents.models import (
    OpenApiTool,
    OpenApiConnectionAuthDetails,
    OpenApiConnectionSecurityScheme
)
```

### Creating OpenAPI Tool from Spec

```python
# Load and modify OpenAPI spec (replace placeholder URLs)
with open("./city-weather-openapi.json", "r") as f:
    openapi_weather = jsonref.loads(
        f.read().replace(
            "https://replace-me.local/weatherservice",
            f"{apim_resource_gateway_url}/weatherservice"
        )
    )

# Create OpenAPI tool with authentication
openapi_tool = OpenApiTool(
    name="get_weather",
    spec=openapi_weather,
    description="Retrieve weather information for a location",
    auth=OpenApiConnectionAuthDetails(
        security_scheme=OpenApiConnectionSecurityScheme(
            connection_id=weather_api_connection_id  # APIM connection
        )
    )
)
```

### Combining Multiple OpenAPI Tools

```python
# First tool - Product Catalog
with open("./product-catalog-openapi.json", "r") as f:
    openapi_product_catalog = jsonref.loads(
        f.read().replace("https://replace-me.local/catalogservice", 
                         f"{apim_resource_gateway_url}/catalogservice")
    )

openapi_tools = OpenApiTool(
    name="get_product_catalog",
    spec=openapi_product_catalog,
    description="Retrieve the list of products available in the catalog",
    auth=OpenApiConnectionAuthDetails(
        security_scheme=OpenApiConnectionSecurityScheme(
            connection_id=product_catalog_api_connection_id
        )
    )
)

# Add second tool - Place Order (using add_definition)
with open("./place-order-openapi.json", "r") as f:
    openapi_place_order = jsonref.loads(
        f.read().replace("https://replace-me.local/orderservice",
                         f"{apim_resource_gateway_url}/orderservice")
    )

openapi_tools.add_definition(
    name="place_order",
    spec=openapi_place_order,
    description="Place a product order",
    auth=OpenApiConnectionAuthDetails(
        security_scheme=OpenApiConnectionSecurityScheme(
            connection_id=place_order_api_connection_id
        )
    )
)

# Create agent with multiple tools
agent = project_client.agents.create_agent(
    model=openai_deployment_name,
    name="my-sales-assistant",
    instructions="You are a helpful sales assistant. Recover from errors and place multiple orders if needed.",
    tools=openapi_tools.definitions  # Contains both tools
)
```

### Inspecting Tool Calls During Run

```python
# After run completes, inspect the steps
run_steps = project_client.agents.list_run_steps(thread_id=thread.id, run_id=run.id)

for step in reversed(run_steps.data):
    print(f"Step {step['id']} status: {step['status']}")
    
    step_details = step.get("step_details", {})
    tool_calls = step_details.get("tool_calls", [])
    
    if tool_calls:
        for call in tool_calls:
            function_details = call.get("function", {})
            if function_details:
                print(f"  Function: {function_details.get('name')}")
                print(f"  Arguments: {function_details.get('arguments')}")
                print(f"  Output: {function_details.get('output')}")
```

---

## 8. Thread and Message Management

### Listing Connections

```python
from azure.ai.projects.models import ConnectionType

with project_client:
    connections = project_client.connections.list()
    for connection in connections:
        # V1
        print(f"Name: {connection.name}, Type: {connection.connection_type}")
        # V2
        print(f"Name: {connection.name}, Id: {connection.id}, Type: {connection.type}")
```

### Getting Specific Connection

```python
# V1
bing_connection = project_client.connections.get(connection_name=bing_search_connection)

# V2
bing_connection = project_client.connections.get(name='bingSearch-connection')
```

### Message Roles

| Role | Usage |
|------|-------|
| `user` | Input from the human user |
| `assistant` | Response from the agent |

### Retrieving Messages

```python
# V1 - Returns object with data attribute
messages = project_client.agents.list_messages(thread_id=thread.id)
response = messages.data[0].content[0].text.value

# V2 - Returns iterable
messages = project_client.agents.messages.list(thread_id=thread.id)
for message in messages:
    print(f"Role: {message.role}, Content: {message.content}")
```

---

## 9. Monitoring with Application Insights

### Enable Azure Monitor Telemetry

```python
from azure.monitor.opentelemetry import configure_azure_monitor

# Get connection string from AI Foundry project
application_insights_connection_string = project_client.telemetry.get_connection_string()

# Configure Azure Monitor
configure_azure_monitor(connection_string=application_insights_connection_string)
```

### Query Custom Metrics with KQL

```python
import pandas as pd

query = """
customMetrics
| where name == 'Total Tokens'
| where timestamp >= ago(1h)
| extend parsedCustomDimensions = parse_json(customDimensions)
| extend apimSubscription = tostring(parsedCustomDimensions.['Subscription ID'])
| extend agentID = tostring(parsedCustomDimensions.['Agent ID'])
| summarize TotalValue = sum(value) by apimSubscription, bin(timestamp, 1m), agentID
| order by timestamp asc
"""

output = utils.run(
    f"az monitor app-insights query --app {app_insights_name} -g {resource_group_name} --analytics-query \"{query}\"",
    "App Insights query succeeded",
    "App Insights query failed"
)

# Parse results into DataFrame
table = output.json_data['tables'][0]
df = pd.DataFrame(
    table.get("rows"),
    columns=[col.get("name") for col in table.get('columns')]
)
```

### Visualize Token Usage

```python
import matplotlib.pyplot as plt

df_pivot = df.pivot(index='timestamp', columns='apimSubscription', values='TotalValue')
ax = df_pivot.plot(kind='bar', stacked=True)
plt.title('Total token usage over time by APIM Subscription')
plt.xlabel('Time')
plt.ylabel('Tokens')
plt.legend(title='APIM Subscription')
plt.show()
```

---

## 10. V1 vs V2 SDK Differences

### Client Initialization

| Aspect | V1 | V2 |
|--------|----|----|
| Package | `azure-ai-projects==1.0.0b10` | `azure-ai-projects==1.0.0b12` |
| Client Creation | `AIProjectClient.from_connection_string()` | `AIProjectClient(endpoint=...)` |
| Authentication | Connection string | Direct endpoint URL |

### API Method Paths

| Operation | V1 | V2 |
|-----------|----|----|
| Create Thread | `project_client.agents.create_thread()` | `project_client.agents.threads.create()` |
| Create Message | `project_client.agents.create_message()` | `project_client.agents.messages.create()` |
| Create Run | `project_client.agents.create_run()` | `project_client.agents.runs.create()` |
| Auto-Process Run | `project_client.agents.create_and_process_run()` | `project_client.agents.runs.create_and_process()` |
| List Messages | `project_client.agents.list_messages()` | `project_client.agents.messages.list()` |
| List Run Steps | `project_client.agents.list_run_steps()` | `project_client.agents.run_steps.list()` |
| Get Run | `project_client.agents.get_run()` | `project_client.agents.runs.get()` |

### Tool Imports

| Tool | V1 | V2 |
|------|----|----|
| Bing | `azure.ai.projects.models.BingGroundingTool` | `azure.ai.agents.models.BingGroundingTool` |
| OpenAPI | `azure.ai.projects.models.OpenApiTool` | `azure.ai.agents.models.OpenApiTool` |
| Code Interpreter | (not shown) | `azure.ai.agents.models.CodeInterpreterTool` |

### Message Response Structure

```python
# V1 - Access via .data attribute
messages = project_client.agents.list_messages(thread_id=thread.id)
response_text = messages.data[0].content[0].text.value

# V2 - Direct iteration, use MessageTextContent type check
from azure.ai.agents.models import MessageTextContent

messages = project_client.agents.messages.list(thread_id=thread.id)
for item in messages:
    last_content = item.content[-1]
    if isinstance(last_content, MessageTextContent):
        print(last_content.text.value)
```

---

## Summary

### Key SDK Patterns

1. **Use context managers** (`with project_client:`) for automatic cleanup
2. **Always delete agents** when done to avoid resource accumulation
3. **Use `create_and_process_run`** for simpler code when you don't need manual tool handling
4. **Poll run status** when using `create_run` directly
5. **Configure Azure Monitor** early for telemetry

### Required Packages

```bash
# V1
pip install azure-ai-projects==1.0.0b10 azure-identity jsonref azure-monitor-opentelemetry

# V2  
pip install azure-ai-projects==1.0.0b12 azure-identity jsonref azure-monitor-opentelemetry
```

---

## Additional Resources

- [Azure AI Agent Service Overview](https://learn.microsoft.com/azure/ai-services/agents/overview)
- [Azure AI Agent Service Quickstart](https://learn.microsoft.com/azure/ai-services/agents/quickstart)
- [Bing Grounding Tool Documentation](https://learn.microsoft.com/azure/ai-services/agents/how-to/tools/bing-grounding)
- [Azure AI Projects SDK Samples](https://github.com/Azure/azure-sdk-for-python/tree/main/sdk/ai/azure-ai-projects/samples)
- [Azure AI Foundry Tracing](https://learn.microsoft.com/azure/ai-studio/concepts/trace)
