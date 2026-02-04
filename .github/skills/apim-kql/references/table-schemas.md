# APIM KQL Table Schemas

Complete column definitions for Azure API Management and Application Insights tables.

## Table of Contents

- [ApiManagementGatewayLogs](#apimanagementgatewaylogs)
- [ApiManagementGatewayLlmLog](#apimanagementgatewayllmlog)
- [ApiManagementGatewayMCPLog](#apimanagementgatewaymcplog)
- [ApiManagementWebSocketConnectionLogs](#apimanagementwebsocketconnectionlogs)
- [AppRequests](#apprequests)
- [AppMetrics](#appmetrics)
- [AppTraces](#apptraces)

---

## ApiManagementGatewayLogs

Azure API Management gateway request/response logs.

### Key Columns

| Column | Type | Description |
|--------|------|-------------|
| `TimeGenerated` | datetime | Timestamp when request processing started |
| `CorrelationId` | string | Unique request ID (use for joining tables) |
| `Method` | string | HTTP method (GET, POST, etc.) |
| `Url` | string | Full request URL |
| `ResponseCode` | int | HTTP response status code |
| `TotalTime` | long | Total request processing time (ms) |
| `BackendTime` | long | Backend processing time (ms) |
| `CacheTime` | long | Cache processing time (ms) |
| `ClientTime` | long | Client processing time (ms) |

### Request/Response Columns

| Column | Type | Description |
|--------|------|-------------|
| `RequestBody` | string | Client request body |
| `RequestHeaders` | dynamic | Request headers |
| `RequestSize` | int | Request size in bytes |
| `ResponseBody` | string | Gateway response body |
| `ResponseHeaders` | dynamic | Response headers |
| `ResponseSize` | int | Response size in bytes |

### Backend Columns

| Column | Type | Description |
|--------|------|-------------|
| `BackendId` | string | Backend identifier |
| `BackendMethod` | string | Backend HTTP method |
| `BackendProtocol` | string | Backend protocol |
| `BackendUrl` | string | Backend URL |
| `BackendRequestBody` | string | Backend request body |
| `BackendRequestHeaders` | dynamic | Backend request headers |
| `BackendResponseBody` | string | Backend response body |
| `BackendResponseCode` | int | Backend response status code |
| `BackendResponseHeaders` | dynamic | Backend response headers |

### Identity Columns

| Column | Type | Description |
|--------|------|-------------|
| `ApiId` | string | API identifier |
| `ApiRevision` | string | API revision |
| `ApimSubscriptionId` | string | APIM subscription identifier |
| `OperationId` | string | Operation identifier |
| `ProductId` | string | Product identifier |
| `UserId` | string | User identifier |
| `CallerIpAddress` | string | Client IP address |
| `ClientProtocol` | string | Client protocol |
| `ClientTlsVersion` | string | Client TLS version |

### Error Columns

| Column | Type | Description |
|--------|------|-------------|
| `Errors` | dynamic | Error details |
| `LastErrorMessage` | string | Last error message |
| `LastErrorReason` | string | Last error reason |
| `LastErrorScope` | string | Last error scope |
| `LastErrorSection` | string | Last error section |
| `LastErrorSource` | string | Last error source |
| `LastErrorElapsed` | long | Time elapsed at error |
| `IsRequestSuccess` | bool | Whether request succeeded |

### Tracing Columns

| Column | Type | Description |
|--------|------|-------------|
| `TraceRecords` | dynamic | Records emitted by trace policies |
| `IsTraceAllowed` | bool | Whether trace was allowed |
| `IsTraceRequested` | bool | Whether trace was requested |
| `IsTraceExpired` | bool | Whether trace has expired |
| `IsMasterTrace` | bool | Whether trace used master subscription |

### Other Columns

| Column | Type | Description |
|--------|------|-------------|
| `Cache` | string | Cache status (hit/miss) |
| `Region` | string | APIM region |
| `WorkspaceId` | string | APIM workspace ID |
| `_ResourceId` | string | Azure resource ID |
| `_SubscriptionId` | string | Azure subscription ID |
| `TenantId` | string | Log Analytics workspace ID |

---

## ApiManagementGatewayLlmLog

Gateway logs for LLM/AI model requests.

### Key Columns

| Column | Type | Description |
|--------|------|-------------|
| `TimeGenerated` | datetime | Timestamp when request processing started |
| `CorrelationId` | string | Unique ID matching ApiManagementGatewayLogs |
| `DeploymentName` | string | Model deployment name |
| `ModelName` | string | Model name used |
| `ApiVersion` | string | API version used by client |

### Token Usage Columns

| Column | Type | Description |
|--------|------|-------------|
| `PromptTokens` | int | Number of prompt/input tokens |
| `CompletionTokens` | int | Number of completion/output tokens |
| `TotalTokens` | int | Total tokens used |

### Request/Response Columns

| Column | Type | Description |
|--------|------|-------------|
| `RequestId` | string | Language model's request ID |
| `RequestMessages` | dynamic | Contents of request messages |
| `ResponseMessages` | dynamic | Contents of response messages |
| `IsStreamCompletion` | bool | Whether stream mode was used |
| `SequenceNumber` | int | Index in message exchange |

### Other Columns

| Column | Type | Description |
|--------|------|-------------|
| `OperationName` | string | Operation identifier |
| `Region` | string | Azure region |
| `_ResourceId` | string | Azure resource ID |
| `_SubscriptionId` | string | Azure subscription ID |
| `TenantId` | string | Log Analytics workspace ID |

---

## ApiManagementGatewayMCPLog

Gateway logs for Model Context Protocol (MCP) requests.

### Key Columns

| Column | Type | Description |
|--------|------|-------------|
| `TimeGenerated` | datetime | Timestamp when request processing started |
| `CorrelationId` | string | Unique ID matching ApiManagementGatewayLogs |
| `Method` | string | MCP method (tools/call, notification) |
| `OperationName` | string | Operation identifier |

### Server Columns

| Column | Type | Description |
|--------|------|-------------|
| `ServerName` | string | MCP server name |
| `ServerVersion` | string | MCP server version |
| `McpServerEndpoint` | string | MCP server endpoint |
| `ProtocolVersion` | string | MCP protocol version |

### Client Columns

| Column | Type | Description |
|--------|------|-------------|
| `ClientName` | string | Client name making request |
| `ClientVersion` | string | Client version |
| `SessionId` | string | AI conversation/agent session ID |

### Tool Columns

| Column | Type | Description |
|--------|------|-------------|
| `ToolName` | string | MCP tool name being used |
| `ToolCount` | int | Number of MCP tools discovered |

### Configuration Columns

| Column | Type | Description |
|--------|------|-------------|
| `ApiType` | string | API type (passthrough, mcp backend) |
| `AuthenticationMethod` | string | Auth method (oauth2, api_key, cert, none) |
| `TransportType` | string | Transport type (SSE, Streamable HTTP) |

### Error Columns

| Column | Type | Description |
|--------|------|-------------|
| `Error` | string | Error message if any |
| `ErrorType` | string | Error type if any |

### Other Columns

| Column | Type | Description |
|--------|------|-------------|
| `Region` | string | Azure region |
| `_ResourceId` | string | Azure resource ID |
| `_SubscriptionId` | string | Azure subscription ID |
| `TenantId` | string | Log Analytics workspace ID |

---

## ApiManagementWebSocketConnectionLogs

WebSocket connection event logs.

### Key Columns

| Column | Type | Description |
|--------|------|-------------|
| `TimeGenerated` | datetime | Timestamp when request processing started |
| `CorrelationId` | string | Unique ID to group related events |
| `EventName` | string | Name of the connection event |
| `Source` | string | Source of request/message |
| `Destination` | string | Destination of request/message |

### Other Columns

| Column | Type | Description |
|--------|------|-------------|
| `Error` | string | Error details if any |
| `Region` | string | Gateway region |
| `_ResourceId` | string | Azure resource ID |
| `_SubscriptionId` | string | Azure subscription ID |
| `TenantId` | string | Log Analytics workspace ID |

---

## AppRequests

Application Insights request telemetry.

### Key Columns

| Column | Type | Description |
|--------|------|-------------|
| `TimeGenerated` | datetime | Timestamp when request processing started |
| `Id` | string | Application-generated unique request ID |
| `OperationId` | string | Application-defined operation ID |
| `OperationName` | string | Operation name (typically matches Name) |
| `Name` | string | Human-readable request name |

### Performance Columns

| Column | Type | Description |
|--------|------|-------------|
| `DurationMs` | real | Request duration in milliseconds |
| `Success` | bool | Whether request was successful |
| `ResultCode` | string | Result code returned by application |

### Request Columns

| Column | Type | Description |
|--------|------|-------------|
| `Url` | string | Request URL |
| `Source` | string | Request source (based on caller metadata) |
| `Properties` | dynamic | Application-defined properties |
| `Measurements` | dynamic | Application-defined measurements |

### Client Columns

| Column | Type | Description |
|--------|------|-------------|
| `ClientIP` | string | Client IP address |
| `ClientCity` | string | Client city |
| `ClientCountryOrRegion` | string | Client country/region |
| `ClientStateOrProvince` | string | Client state/province |
| `ClientBrowser` | string | Client browser |
| `ClientOS` | string | Client operating system |
| `ClientModel` | string | Client device model |
| `ClientType` | string | Client device type |

### User Columns

| Column | Type | Description |
|--------|------|-------------|
| `UserId` | string | Anonymous user ID |
| `UserAuthenticatedId` | string | Authenticated user ID |
| `UserAccountId` | string | User account ID |
| `SessionId` | string | Session ID |

### Application Columns

| Column | Type | Description |
|--------|------|-------------|
| `AppRoleName` | string | Application role name |
| `AppRoleInstance` | string | Application role instance |
| `AppVersion` | string | Application version |
| `SDKVersion` | string | SDK version |
| `IKey` | string | Instrumentation key |

---

## AppMetrics

Application Insights custom metrics.

### Key Columns

| Column | Type | Description |
|--------|------|-------------|
| `TimeGenerated` | datetime | Timestamp when metric was generated |
| `Name` | string | Application-defined metric name |
| `OperationId` | string | Operation ID |
| `OperationName` | string | Operation name |

### Metric Value Columns

| Column | Type | Description |
|--------|------|-------------|
| `Sum` | real | Sum of measurements |
| `Min` | real | Minimum value |
| `Max` | real | Maximum value |
| `ItemCount` | int | Number of measurements aggregated |

### Application Columns

| Column | Type | Description |
|--------|------|-------------|
| `AppRoleName` | string | Application role name |
| `AppRoleInstance` | string | Application role instance |
| `AppVersion` | string | Application version |
| `Properties` | dynamic | Application-defined properties |

### Client Columns

| Column | Type | Description |
|--------|------|-------------|
| `ClientIP` | string | Client IP address |
| `ClientCity` | string | Client city |
| `ClientCountryOrRegion` | string | Client country/region |
| `ClientBrowser` | string | Client browser |
| `ClientOS` | string | Client operating system |

---

## AppTraces

Application Insights trace messages.

### Key Columns

| Column | Type | Description |
|--------|------|-------------|
| `TimeGenerated` | datetime | Timestamp when trace was recorded |
| `Message` | string | Trace message |
| `SeverityLevel` | int | Severity level (0-4) |
| `OperationId` | string | Operation ID |
| `OperationName` | string | Operation name |

### Context Columns

| Column | Type | Description |
|--------|------|-------------|
| `Properties` | dynamic | Application-defined properties |
| `Measurements` | dynamic | Application-defined measurements |
| `ParentId` | string | Parent operation ID |
| `SessionId` | string | Session ID |

### Application Columns

| Column | Type | Description |
|--------|------|-------------|
| `AppRoleName` | string | Application role name |
| `AppRoleInstance` | string | Application role instance |
| `AppVersion` | string | Application version |
| `SDKVersion` | string | SDK version |

### Severity Levels

| Level | Value | Description |
|-------|-------|-------------|
| Verbose | 0 | Detailed diagnostic information |
| Information | 1 | Informational messages |
| Warning | 2 | Warning conditions |
| Error | 3 | Error conditions |
| Critical | 4 | Critical failures |

---

## Common Columns (All Tables)

| Column | Type | Description |
|--------|------|-------------|
| `TimeGenerated` | datetime | Record timestamp |
| `_ResourceId` | string | Azure resource ID |
| `_SubscriptionId` | string | Azure subscription ID |
| `TenantId` | string | Log Analytics workspace ID |
| `Type` | string | Table name |
| `_BilledSize` | real | Record size in bytes |
| `_IsBillable` | string | Whether ingestion is billable |
| `SourceSystem` | string | Collection agent type |
