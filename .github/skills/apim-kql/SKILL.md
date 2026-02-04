---
name: apim-kql
description: Guide for creating Kusto Query Language (KQL) queries for Azure API Management tables in Azure Monitor (Log Analytics Workspace). Use when users want to query, analyze, or monitor APIM logs including gateway logs, LLM/AI logs, MCP logs, WebSocket logs, and Application Insights data. This skill provides KQL syntax, table schemas, and query patterns for APIM monitoring scenarios.
---

# APIM KQL Skill

Guide for creating Kusto Query Language (KQL) queries for Azure API Management monitoring data in Azure Monitor.

## Quick Start

### Basic Gateway Logs Query

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| project TimeGenerated, Method, Url, ResponseCode, TotalTime, BackendTime, CallerIpAddress
| order by TimeGenerated desc
| take 100
```

### LLM Token Usage Query

```kql
ApiManagementGatewayLlmLog
| where TimeGenerated > ago(24h)
| summarize 
    TotalPromptTokens = sum(PromptTokens),
    TotalCompletionTokens = sum(CompletionTokens),
    TotalTokens = sum(TotalTokens)
by DeploymentName, ModelName
```

## Tables Overview

| Table | Description | Use Case |
|-------|-------------|----------|
| `ApiManagementGatewayLogs` | Gateway request/response logs | API traffic analysis, errors, latency |
| `ApiManagementGatewayLlmLog` | LLM/AI model usage logs | Token usage, model performance |
| `ApiManagementGatewayMCPLog` | MCP server logs | MCP tool calls, sessions |
| `ApiManagementWebSocketConnectionLogs` | WebSocket connection events | Real-time API monitoring |
| `AppRequests` | Application Insights requests | End-to-end request tracking |
| `AppMetrics` | Application Insights metrics | Custom metrics analysis |
| `AppTraces` | Application Insights traces | Debug and diagnostic traces |

For complete table schemas, see [references/table-schemas.md](references/table-schemas.md).

## Essential Query Patterns

### Joining LLM Logs with Gateway Logs

```kql
let llmLogs = ApiManagementGatewayLlmLog 
| where DeploymentName != '';

let logsWithSubscription = llmLogs 
| join kind=leftouter ApiManagementGatewayLogs on CorrelationId 
| project 
    SubscriptionId = ApimSubscriptionId, 
    DeploymentName, 
    ModelName,
    PromptTokens, 
    CompletionTokens, 
    TotalTokens;

logsWithSubscription 
| summarize 
    SumPromptTokens = sum(PromptTokens), 
    SumCompletionTokens = sum(CompletionTokens), 
    SumTotalTokens = sum(TotalTokens) 
by SubscriptionId, DeploymentName
```

### Error Analysis

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(24h)
| where ResponseCode >= 400
| summarize ErrorCount = count() by ResponseCode, ApiId, LastErrorReason
| order by ErrorCount desc
```

### Request Latency Analysis

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| summarize 
    AvgTotalTime = avg(TotalTime),
    AvgBackendTime = avg(BackendTime),
    P95TotalTime = percentile(TotalTime, 95),
    RequestCount = count()
by bin(TimeGenerated, 5m), ApiId
| order by TimeGenerated desc
```

### Backend Performance

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| where BackendId != ""
| summarize 
    AvgBackendTime = avg(BackendTime),
    MaxBackendTime = max(BackendTime),
    ErrorCount = countif(BackendResponseCode >= 400),
    TotalRequests = count()
by BackendId
| order by AvgBackendTime desc
```

### Token Usage by Time

```kql
ApiManagementGatewayLlmLog
| where TimeGenerated > ago(7d)
| summarize 
    TotalTokens = sum(TotalTokens),
    PromptTokens = sum(PromptTokens),
    CompletionTokens = sum(CompletionTokens)
by bin(TimeGenerated, 1h), DeploymentName
| order by TimeGenerated desc
```

### MCP Tool Usage

```kql
ApiManagementGatewayMCPLog
| where TimeGenerated > ago(24h)
| summarize 
    CallCount = count(),
    UniqueClients = dcount(ClientName)
by ToolName, ServerName, Method
| order by CallCount desc
```

### WebSocket Connection Events

```kql
ApiManagementWebSocketConnectionLogs
| where TimeGenerated > ago(1h)
| summarize 
    EventCount = count()
by EventName, Source, Destination
| order by EventCount desc
```

## KQL Operators Reference

### Filtering

```kql
| where TimeGenerated > ago(1h)
| where ResponseCode == 200
| where ApiId contains "openai"
| where isnotempty(BackendId)
```

### Aggregation

```kql
| summarize count() by ApiId
| summarize avg(TotalTime), percentile(TotalTime, 95) by ApiId
| summarize sum(TotalTokens) by DeploymentName
| summarize dcount(CallerIpAddress) by bin(TimeGenerated, 1h)
```

### Time Functions

```kql
| where TimeGenerated > ago(1h)
| where TimeGenerated between (datetime(2024-01-01) .. datetime(2024-01-31))
| where TimeGenerated >= startofmonth(now()) and TimeGenerated <= endofmonth(now())
| summarize ... by bin(TimeGenerated, 5m)
```

### Joins

```kql
| join kind=leftouter OtherTable on CorrelationId
| join kind=inner OtherTable on $left.Field1 == $right.Field2
```

### Projections

```kql
| project TimeGenerated, Method, Url, ResponseCode
| project-away _BilledSize, _IsBillable
| extend Duration = TotalTime - BackendTime
| extend IsError = ResponseCode >= 400
```

### Ordering and Limiting

```kql
| order by TimeGenerated desc
| take 100
| top 10 by TotalTime desc
```

## Common Scenarios

### Daily Request Summary

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(7d)
| summarize 
    TotalRequests = count(),
    SuccessfulRequests = countif(ResponseCode < 400),
    FailedRequests = countif(ResponseCode >= 400),
    AvgLatency = avg(TotalTime)
by bin(TimeGenerated, 1d), ApiId
| extend SuccessRate = round(100.0 * SuccessfulRequests / TotalRequests, 2)
| order by TimeGenerated desc
```

### Top Consumers by Token Usage

```kql
let llmLogs = ApiManagementGatewayLlmLog 
| where TimeGenerated > ago(30d);

llmLogs 
| join kind=leftouter ApiManagementGatewayLogs on CorrelationId 
| summarize 
    TotalTokens = sum(TotalTokens),
    RequestCount = count()
by ApimSubscriptionId
| top 10 by TotalTokens desc
```

### Error Rate Over Time

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(24h)
| summarize 
    Total = count(),
    Errors = countif(ResponseCode >= 400)
by bin(TimeGenerated, 1h)
| extend ErrorRate = round(100.0 * Errors / Total, 2)
| project TimeGenerated, Total, Errors, ErrorRate
| order by TimeGenerated desc
```

### Cache Hit Analysis

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(24h)
| where Cache != ""
| summarize 
    HitCount = countif(Cache == "hit"),
    MissCount = countif(Cache == "miss")
by ApiId
| extend HitRate = round(100.0 * HitCount / (HitCount + MissCount), 2)
```

### Streaming vs Non-Streaming LLM Requests

```kql
ApiManagementGatewayLlmLog
| where TimeGenerated > ago(24h)
| summarize 
    StreamingRequests = countif(IsStreamCompletion == true),
    NonStreamingRequests = countif(IsStreamCompletion == false),
    AvgTokens = avg(TotalTokens)
by DeploymentName
```

## Running KQL Queries

### Azure CLI

```bash
az monitor log-analytics query \
  -w <workspace-id> \
  --analytics-query "ApiManagementGatewayLogs | take 10"
```

### Python

```python
query = """
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| take 100
"""
result = utils.run(f'az monitor log-analytics query -w {workspace_id} --analytics-query "{query}"')
```

## Best Practices

1. **Always filter by time** - Use `where TimeGenerated > ago(...)` to limit data scanned
2. **Use summarize early** - Aggregate data before joins when possible
3. **Project only needed columns** - Reduce data transfer with explicit projections
4. **Use let statements** - Break complex queries into readable parts
5. **Join on CorrelationId** - Link APIM tables together using this common key
6. **Use bin() for time series** - Group time data into meaningful intervals

## References

- [references/table-schemas.md](references/table-schemas.md) - Complete table column definitions
- [references/query-examples.md](references/query-examples.md) - Additional query examples from this repository
