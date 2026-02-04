# APIM KQL Query Examples

Real-world query examples from the AI Gateway repository.

## Table of Contents

- [LLM Token Usage Queries](#llm-token-usage-queries)
- [Cost Analysis Queries](#cost-analysis-queries)
- [Gateway Analytics Queries](#gateway-analytics-queries)
- [Dashboard Queries](#dashboard-queries)

---

## LLM Token Usage Queries

### Token Usage by Subscription and Deployment

From `labs/built-in-logging/`:

```kql
let llmHeaderLogs = ApiManagementGatewayLlmLog 
| where DeploymentName != '';

let llmLogsWithSubscriptionId = llmHeaderLogs 
| join kind=leftouter ApiManagementGatewayLogs on CorrelationId 
| project 
    SubscriptionId = ApimSubscriptionId, 
    DeploymentName, 
    ModelName,
    TotalTokens;

llmLogsWithSubscriptionId 
| summarize 
    SumTotalTokens = sum(TotalTokens) 
by SubscriptionId, DeploymentName, ModelName
```

### Token Usage Summary

From `labs/realtime-audio/` and `labs/aws-bedrock/`:

```kql
let llmHeaderLogs = ApiManagementGatewayLlmLog 
| where DeploymentName != '';

let llmLogsWithSubscriptionId = llmHeaderLogs 
| join kind=leftouter ApiManagementGatewayLogs on CorrelationId 
| project 
    SubscriptionId = ApimSubscriptionId, 
    DeploymentName, 
    PromptTokens, 
    CompletionTokens, 
    TotalTokens;

llmLogsWithSubscriptionId 
| summarize 
    SumPromptTokens = sum(PromptTokens), 
    SumCompletionTokens = sum(CompletionTokens), 
    SumTotalTokens = sum(TotalTokens) 
by SubscriptionId, DeploymentName
```

---

## Cost Analysis Queries

### Monthly Cost by Subscription

From `labs/finops-framework/`:

```kql
let llmHeaderLogs = ApiManagementGatewayLlmLog
| where TimeGenerated >= startofmonth(now()) and TimeGenerated <= endofmonth(now())
| where DeploymentName != "";

let llmLogsWithSubscriptionId = llmHeaderLogs
| join kind=leftouter ApiManagementGatewayLogs on CorrelationId
| project
    SubscriptionName = ApimSubscriptionId, 
    DeploymentName, 
    PromptTokens, 
    CompletionTokens, 
    TotalTokens;

llmLogsWithSubscriptionId
| join kind=inner (
    PRICING_CL
    | summarize arg_max(TimeGenerated, *) by Model
    | project Model, InputTokensPrice, OutputTokensPrice
)
on $left.DeploymentName == $right.Model
| extend InputCost = PromptTokens * InputTokensPrice
| extend OutputCost = CompletionTokens * OutputTokensPrice
| summarize
    TotalInputCost = sum(InputCost),
    TotalOutputCost = sum(OutputCost)
by SubscriptionName, DeploymentName
| extend TotalCost = TotalInputCost + TotalOutputCost
```

### Cost Trend Over Time

From `labs/finops-framework/`:

```kql
let llmHeaderLogs = ApiManagementGatewayLlmLog
| where DeploymentName != '';

let llmLogsWithSubscriptionId = llmHeaderLogs
| join kind=leftouter ApiManagementGatewayLogs on CorrelationId
| project
    TimeGenerated, 
    SubscriptionName = ApimSubscriptionId, 
    DeploymentName, 
    PromptTokens, 
    CompletionTokens, 
    TotalTokens;

llmLogsWithSubscriptionId
| join kind=inner (
    PRICING_CL
    | summarize arg_max(TimeGenerated, *) by Model
    | project Model, InputTokensPrice, OutputTokensPrice
)
on $left.DeploymentName == $right.Model
| extend InputCost = PromptTokens * InputTokensPrice
| extend OutputCost = CompletionTokens * OutputTokensPrice
| summarize
    TotalInputCost = sum(InputCost),
    TotalOutputCost = sum(OutputCost)
by bin(TimeGenerated, 1d), SubscriptionName
| extend TotalCost = TotalInputCost + TotalOutputCost
| order by TimeGenerated desc
```

---

## Gateway Analytics Queries

### Request Volume by API

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(24h)
| summarize 
    RequestCount = count(),
    AvgLatency = avg(TotalTime),
    P95Latency = percentile(TotalTime, 95),
    ErrorRate = round(100.0 * countif(ResponseCode >= 400) / count(), 2)
by ApiId
| order by RequestCount desc
```

### Backend Health Check

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| where BackendId != ""
| summarize 
    TotalRequests = count(),
    SuccessfulRequests = countif(BackendResponseCode < 400),
    FailedRequests = countif(BackendResponseCode >= 400),
    Avg429Responses = countif(BackendResponseCode == 429)
by BackendId
| extend SuccessRate = round(100.0 * SuccessfulRequests / TotalRequests, 2)
| order by FailedRequests desc
```

### Cache Efficiency

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(24h)
| where Cache != ""
| summarize 
    CacheHits = countif(Cache == "hit"),
    CacheMisses = countif(Cache == "miss")
by ApiId
| extend TotalRequests = CacheHits + CacheMisses
| extend CacheHitRate = round(100.0 * CacheHits / TotalRequests, 2)
| order by CacheHitRate desc
```

### Error Analysis by Reason

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(24h)
| where ResponseCode >= 400
| summarize 
    ErrorCount = count()
by ResponseCode, LastErrorReason, LastErrorSection
| order by ErrorCount desc
| take 20
```

### Client IP Analysis

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| summarize 
    RequestCount = count(),
    UniqueAPIs = dcount(ApiId)
by CallerIpAddress
| order by RequestCount desc
| take 50
```

---

## Dashboard Queries

### Real-Time Request Monitor

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(5m)
| summarize 
    RequestsPerMinute = count()
by bin(TimeGenerated, 1m)
| order by TimeGenerated desc
```

### API Health Overview

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| summarize 
    TotalRequests = count(),
    AvgResponseTime = avg(TotalTime),
    P99ResponseTime = percentile(TotalTime, 99),
    ErrorCount = countif(ResponseCode >= 400),
    ThrottledCount = countif(ResponseCode == 429)
by ApiId
| extend 
    ErrorRate = round(100.0 * ErrorCount / TotalRequests, 2),
    ThrottleRate = round(100.0 * ThrottledCount / TotalRequests, 2)
| project 
    ApiId, 
    TotalRequests, 
    AvgResponseTime = round(AvgResponseTime, 0),
    P99ResponseTime = round(P99ResponseTime, 0),
    ErrorRate,
    ThrottleRate
| order by TotalRequests desc
```

### LLM Usage Dashboard

```kql
ApiManagementGatewayLlmLog
| where TimeGenerated > ago(24h)
| summarize 
    TotalRequests = count(),
    TotalPromptTokens = sum(PromptTokens),
    TotalCompletionTokens = sum(CompletionTokens),
    TotalTokens = sum(TotalTokens),
    StreamingRequests = countif(IsStreamCompletion == true)
by DeploymentName, ModelName
| extend 
    AvgTokensPerRequest = round(1.0 * TotalTokens / TotalRequests, 0),
    StreamingRate = round(100.0 * StreamingRequests / TotalRequests, 2)
| order by TotalTokens desc
```

### MCP Tool Usage Dashboard

```kql
ApiManagementGatewayMCPLog
| where TimeGenerated > ago(24h)
| summarize 
    TotalCalls = count(),
    UniqueSessions = dcount(SessionId),
    UniqueClients = dcount(ClientName),
    ErrorCount = countif(isnotempty(Error))
by ServerName, ToolName
| extend ErrorRate = round(100.0 * ErrorCount / TotalCalls, 2)
| order by TotalCalls desc
```

---

## Time-Based Analysis

### Hourly Traffic Pattern

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(7d)
| extend Hour = hourofday(TimeGenerated)
| summarize RequestCount = count() by Hour
| order by Hour asc
```

### Weekly Trend

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(30d)
| summarize 
    RequestCount = count(),
    AvgLatency = avg(TotalTime)
by bin(TimeGenerated, 1d)
| order by TimeGenerated asc
```

### Peak Usage Times

```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(7d)
| extend 
    DayOfWeek = dayofweek(TimeGenerated),
    Hour = hourofday(TimeGenerated)
| summarize RequestCount = count() by DayOfWeek, Hour
| order by RequestCount desc
| take 10
```

---

## Joining Multiple Tables

### Complete Request Analysis (Gateway + LLM)

```kql
let gatewayLogs = ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| project 
    CorrelationId,
    TimeGenerated,
    Method,
    Url,
    ResponseCode,
    TotalTime,
    BackendTime,
    ApimSubscriptionId,
    CallerIpAddress;

let llmLogs = ApiManagementGatewayLlmLog
| where TimeGenerated > ago(1h)
| project 
    CorrelationId,
    DeploymentName,
    ModelName,
    PromptTokens,
    CompletionTokens,
    TotalTokens;

gatewayLogs
| join kind=leftouter llmLogs on CorrelationId
| project 
    TimeGenerated,
    Method,
    Url,
    ResponseCode,
    TotalTime,
    BackendTime,
    DeploymentName,
    ModelName,
    TotalTokens,
    ApimSubscriptionId,
    CallerIpAddress
| order by TimeGenerated desc
```

### MCP with Gateway Context

```kql
let mcpLogs = ApiManagementGatewayMCPLog
| where TimeGenerated > ago(24h)
| project 
    CorrelationId,
    ServerName,
    ToolName,
    Method,
    SessionId;

let gatewayLogs = ApiManagementGatewayLogs
| where TimeGenerated > ago(24h)
| project 
    CorrelationId,
    TotalTime,
    ResponseCode,
    ApimSubscriptionId;

mcpLogs
| join kind=leftouter gatewayLogs on CorrelationId
| summarize 
    CallCount = count(),
    AvgLatency = avg(TotalTime),
    ErrorCount = countif(ResponseCode >= 400)
by ServerName, ToolName
| order by CallCount desc
```
