# AI Gateway Policy Examples

Real-world APIM policy examples from the AI Gateway repository labs. These patterns demonstrate common scenarios for managing AI services through Azure API Management.

## Table of Contents

- [Basic Patterns](#basic-patterns)
- [Authentication Patterns](#authentication-patterns)
- [Load Balancing and Retry](#load-balancing-and-retry)
- [Token Rate Limiting](#token-rate-limiting)
- [Semantic Caching](#semantic-caching)
- [Content Safety](#content-safety)
- [Token Metrics](#token-metrics)
- [Model Routing](#model-routing)
- [Production-Ready Policy](#production-ready-policy)

---

## Basic Patterns

### Minimal Policy with Backend

The simplest policy that routes to a backend:

```xml
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="{backend-id}" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Source:** [labs/built-in-logging/policy.xml](../../../labs/built-in-logging/policy.xml)

---

## Authentication Patterns

### Managed Identity for Azure Cognitive Services

Authenticate to Azure OpenAI or Azure AI Services using APIM's managed identity:

```xml
<policies>
    <inbound>
        <base />
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" 
            output-token-variable-name="managed-id-access-token" ignore-error="false" />
        <set-header name="Authorization" exists-action="override">
            <value>@("Bearer " + (string)context.Variables["managed-id-access-token"])</value>
        </set-header>
        <set-backend-service backend-id="{backend-id}" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Source:** [labs/function-calling/policy.xml](../../../labs/function-calling/policy.xml)

**Use case:** When APIM needs to call Azure OpenAI/AI Services on behalf of clients without passing through client credentials.

### Azure AD Token Validation

Validate client tokens before forwarding requests:

```xml
<policies>
    <inbound>
        <base />
        <validate-azure-ad-token tenant-id="{tenant-id}">
            <client-application-ids>
                <application-id>{client-application-id}</application-id>
            </client-application-ids>
        </validate-azure-ad-token>
        <set-backend-service backend-id="{backend-id}" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Source:** [labs/access-controlling/policy.xml](../../../labs/access-controlling/policy.xml)

**Use case:** Restrict API access to specific Azure AD applications only.

---

## Load Balancing and Retry

### Backend Pool with Automatic Failover

Handle 429 (rate limit) and 503 (service unavailable) errors with automatic retry across backend pool:

```xml
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="{backend-id}" />
    </inbound>
    <backend>
        <!--Set count to one less than the number of backends in the pool-->
        <retry count="2" interval="0" first-fast-retry="true" 
            condition="@(context.Response.StatusCode == 429 || 
                        (context.Response.StatusCode == 503 && 
                         !context.Response.StatusReason.Contains("Backend pool") && 
                         !context.Response.StatusReason.Contains("is temporarily unavailable")))">
            <!--Switch back to same backend pool which will have automatically removed the faulty backend -->
            <set-backend-service backend-id="{backend-id}" />
            <forward-request buffer-request-body="true" />
        </retry>
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
        <choose>
            <!--Return a generic error that does not reveal backend pool details-->
            <when condition="@(context.Response.StatusCode == 503)">
                <return-response>
                    <set-status code="503" reason="Service Unavailable" />
                </return-response>
            </when>
        </choose>
    </on-error>
</policies>
```

**Source:** [labs/backend-pool-load-balancing/policy.xml](../../../labs/backend-pool-load-balancing/policy.xml)

**Key points:**
- `count="2"` for 3 backends (retries 2 times + original = 3 attempts)
- `first-fast-retry="true"` retries immediately without delay
- `buffer-request-body="true"` required for retry to resend the body
- On-error section masks internal backend pool details from clients

---

## Token Rate Limiting

### LLM Token Rate Limiting

Limit token consumption per subscription:

```xml
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="{backend-id}" />
        <llm-token-limit counter-key="@(context.Subscription.Id)"
            tokens-per-minute="100" estimate-prompt-tokens="false" 
            remaining-tokens-variable-name="remainingTokens">
        </llm-token-limit>        
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Source:** [labs/token-rate-limiting/policy.xml](../../../labs/token-rate-limiting/policy.xml)

**Policy variants:**
- `llm-token-limit` - Generic LLM provider
- `azure-openai-token-limit` - Azure OpenAI specific

---

## Semantic Caching

### Azure OpenAI Semantic Caching

Cache responses based on semantic similarity of prompts:

```xml
<policies>
    <inbound>
        <base />
        <!-- Check the embeddings in the Redis cache for a cached prompt response -->
        <azure-openai-semantic-cache-lookup score-threshold="0.8" 
            embeddings-backend-id="embeddings-backend" 
            embeddings-backend-auth="system-assigned" />
        <set-backend-service backend-id="{backend-id}" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <!-- Cache the Gen AI response in Redis for 2 minutes -->
        <azure-openai-semantic-cache-store duration="120" />
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Source:** [labs/semantic-caching/policy.xml](../../../labs/semantic-caching/policy.xml)

**Key points:**
- `score-threshold="0.8"` - Similarity threshold (0.0-1.0)
- `embeddings-backend-id` - Backend for generating embeddings
- `embeddings-backend-auth="system-assigned"` - Use managed identity
- `duration="120"` - Cache TTL in seconds

---

## Content Safety

### LLM Content Safety with Azure AI Content Safety

Block harmful content before sending to LLM:

```xml
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="{backend-id}" />
        <llm-content-safety backend-id="content-safety-backend" shield-prompt="true">
            <categories output-type="EightSeverityLevels">
                <category name="SelfHarm" threshold="4" />
                <category name="Hate" threshold="4" />
                <category name="Violence" threshold="4" />
                <category name="Sexual" threshold="4" />
            </categories>
            <blocklists>
                <id>blocklist1</id>            
            </blocklists>   
        </llm-content-safety>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Source:** [labs/content-safety/policy.xml](../../../labs/content-safety/policy.xml)

**Key points:**
- `shield-prompt="true"` - Enable prompt shielding
- `output-type="EightSeverityLevels"` - Use 0-7 severity scale
- `threshold="4"` - Block content at severity 4+ (moderate or higher)
- Custom blocklists can be added for organization-specific terms

---

## Token Metrics

### Emit Token Usage Metrics

Track LLM token consumption in Application Insights:

```xml
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="{backend-id}" />
        <azure-openai-emit-token-metric namespace="openai">
            <dimension name="Subscription ID" value="@(context.Subscription.Id)" />
            <dimension name="Client IP" value="@(context.Request.IpAddress)" />
            <dimension name="API ID" value="@(context.Api.Id)" />
            <dimension name="User ID" value="@(context.Request.Headers.GetValueOrDefault("x-user-id", "N/A"))" />
        </azure-openai-emit-token-metric>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Source:** [labs/token-metrics-emitting/policy.xml](../../../labs/token-metrics-emitting/policy.xml)

**Common dimensions:**
- `Subscription ID` - Track usage per subscription
- `Client IP` - Geographic/source analysis
- `API ID` - Track per API
- `User ID` - Custom header for user tracking
- `Model` - Track per model deployment

---

## Model Routing

### Dynamic Model-Based Routing

Route requests to different backends based on model name in URL or body:

```xml
<policies>
    <inbound>
        <base />
        <!-- 1a – deployment-id from the route template -->
        <set-variable name="deployment" value="@(context.Request.MatchedParameters.ContainsKey("deployment-id") 
                           ? context.Request.MatchedParameters["deployment-id"] 
                           : string.Empty)" />
        <!-- 1b – model from the request body (JSON) -->
        <set-variable name="reqBody" value="@(context.Request.Body?.As<JObject>(preserveContent:true) 
                           ?? new JObject())" />
        <set-variable name="model" value="@( ((JObject)context.Variables["reqBody"])
                              .Property("model")?.Value?.ToString() 
                              ?? string.Empty)" />
        <!-- 1c – first non-empty of deployment-id or model -->
        <set-variable name="requestedModel" value="@( !string.IsNullOrEmpty((string)context.Variables["deployment"]) 
                           ? (string)context.Variables["deployment"]
                           : (string)context.Variables["model"] )" />
        <!-- 2. Decide what to do with the request -->
        <choose>
            <!-- Route GPT-4.1 to foundry1 -->
            <when condition="@( ((string)context.Variables["requestedModel"]) == "gpt-4.1")">
                <set-backend-service backend-id="foundry1" />
            </when>
            <!-- Route smaller models to foundry2 -->
            <when condition="@( ((string)context.Variables["requestedModel"]) == "gpt-4.1-mini" 
                         || ((string)context.Variables["requestedModel"]) == "gpt-4.1-nano")">
                <set-backend-service backend-id="foundry2" />
            </when>
            <!-- Route special models to foundry3 -->
            <when condition="@( ((string)context.Variables["requestedModel"]) == "model-router"
                            || ((string)context.Variables["requestedModel"]) == "gpt-5"
                            || ((string)context.Variables["requestedModel"]) == "DeepSeek-R1")">
                <set-backend-service backend-id="foundry3" />
            </when>
            <!-- Block deprecated models -->
            <when condition="@( ((string)context.Variables["requestedModel"] ?? string.Empty)
                           .StartsWith("gpt-4o"))">
                <return-response>
                    <set-status code="403" reason="Forbidden" />
                    <set-body>@("{\"error\":\"Model '" + (string)context.Variables["requestedModel"] + "' is not permitted.\"}")</set-body>
                </return-response>
            </when>
            <!-- Catch-all for unknown models -->
            <otherwise>
                <return-response>
                    <set-status code="400" reason="Bad Request" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>{
              "error": "Invalid model or deployment-id. Supply a valid name in the URL or JSON body."
            }</set-body>
                </return-response>
            </otherwise>
        </choose>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Source:** [labs/model-routing/policy.xml](../../../labs/model-routing/policy.xml)

**Use cases:**
- Route to different Azure regions based on model
- Block deprecated or unauthorized models
- Implement tiered access to different model capabilities

---

## Production-Ready Policy

### Complete AI Gateway Policy

Combines multiple patterns for production deployments:

```xml
<policies>
    <inbound>
        <base />
        <!--Policy 4 - Semantic Caching-->
        <azure-openai-semantic-cache-lookup score-threshold="0.8" 
            embeddings-backend-id="embeddings-backend" 
            embeddings-backend-auth="system-assigned" />
        <!-- Authenticate to Azure OpenAI with API Management's managed identity -->
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" 
            output-token-variable-name="managed-id-access-token" ignore-error="false" />
        <set-header name="Authorization" exists-action="override">
            <value>@("Bearer " + (string)context.Variables["managed-id-access-token"])</value>
        </set-header>
        <set-backend-service backend-id="{backend-id}" />
        <!--Policy 3 - Limit the tokens per subscription-->
        <azure-openai-token-limit counter-key="@(context.Subscription.Id)" 
            tokens-per-minute="{tpm}" estimate-prompt-tokens="false" 
            remaining-tokens-variable-name="remainingTokens" />
        <!--Policy 2 - Emit the Azure OpenAI Token Metrics -->
        <azure-openai-emit-token-metric namespace="openai">
            <dimension name="Subscription ID" value="@(context.Subscription.Id)" />
            <dimension name="Client IP" value="@(context.Request.IpAddress)" />
            <dimension name="API ID" value="@(context.Api.Id)" />
            <dimension name="User ID" value="@(context.Request.Headers.GetValueOrDefault("x-user-id", "N/A"))" />
        </azure-openai-emit-token-metric>
    </inbound>
    <backend>
        <!--Policy 1 - Apply load-balancing and retry mechanisms -->
        <retry count="{retry-count}" interval="0" first-fast-retry="true" 
            condition="@(context.Response.StatusCode == 429 || 
                        (context.Response.StatusCode == 503 && 
                         !context.Response.StatusReason.Contains("Backend pool") && 
                         !context.Response.StatusReason.Contains("is temporarily unavailable")))">
            <forward-request buffer-request-body="true" />
        </retry>
    </backend>
    <outbound>
        <!-- Cache the Gen AI response in Redis -->
        <azure-openai-semantic-cache-store duration="120" />
        <base />
    </outbound>
    <on-error>
        <base />
        <choose>
            <!--Return a generic error that does not reveal backend pool details-->
            <when condition="@(context.Response.StatusCode == 503)">
                <return-response>
                    <set-status code="503" reason="Service Unavailable" />
                </return-response>
            </when>
        </choose>
    </on-error>
</policies>
```

**Source:** [labs/zero-to-production/policy-4.xml](../../../labs/zero-to-production/policy-4.xml)

**Features combined:**
1. **Load balancing** - Backend pool with retry
2. **Token metrics** - Usage tracking in Application Insights
3. **Token rate limiting** - Prevent abuse
4. **Semantic caching** - Reduce backend calls and latency
5. **Managed identity auth** - Secure backend authentication
6. **Error handling** - Mask internal errors from clients

---

## Common Placeholders

These placeholders are used in policy templates and should be replaced with actual values:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{backend-id}` | Backend or backend pool ID | `openai-backend-pool` |
| `{tenant-id}` | Azure AD tenant ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `{client-application-id}` | Azure AD app registration ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `{tpm}` | Tokens per minute limit | `10000` |
| `{retry-count}` | Number of retry attempts | `2` |
