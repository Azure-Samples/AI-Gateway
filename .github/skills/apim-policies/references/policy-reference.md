# APIM Policy Reference

Complete reference for Azure API Management policies organized by category.

## Table of Contents

- [Authentication and Authorization](#authentication-and-authorization)
- [Rate Limiting and Quotas](#rate-limiting-and-quotas)
- [Caching](#caching)
- [Routing](#routing)
- [Transformation](#transformation)
- [AI Gateway](#ai-gateway)
- [Content Validation](#content-validation)
- [Cross-Domain](#cross-domain)
- [Integration and External Communication](#integration-and-external-communication)
- [Logging](#logging)
- [Policy Control and Flow](#policy-control-and-flow)

---

## Authentication and Authorization

### authentication-managed-identity

Authenticate with a backend service using APIM's managed identity.

```xml
<authentication-managed-identity 
    resource="https://cognitiveservices.azure.com" 
    output-token-variable-name="managed-id-access-token" 
    ignore-error="false" />
```

**Attributes:**
- `resource`: Target resource URI (required)
- `output-token-variable-name`: Variable to store the token
- `ignore-error`: Continue on failure (true/false)
- `client-id`: Specific user-assigned managed identity client ID

### authentication-basic

Authenticate with backend using Basic authentication.

```xml
<authentication-basic username="username" password="password" />
```

### authentication-certificate

Authenticate with backend using a client certificate.

```xml
<authentication-certificate thumbprint="certificate-thumbprint" />
<!-- Or by certificate ID -->
<authentication-certificate certificate-id="certificate-id" />
```

### validate-azure-ad-token

Validate a JWT token issued by Microsoft Entra ID.

```xml
<validate-azure-ad-token tenant-id="{tenant-id}" 
    header-name="Authorization" 
    failed-validation-httpcode="401" 
    failed-validation-error-message="Unauthorized">
    <client-application-ids>
        <application-id>{app-id}</application-id>
    </client-application-ids>
    <audiences>
        <audience>{audience}</audience>
    </audiences>
    <required-claims>
        <claim name="roles" match="any">
            <value>Reader</value>
            <value>Writer</value>
        </claim>
    </required-claims>
</validate-azure-ad-token>
```

### validate-jwt

Validate any JWT token.

```xml
<validate-jwt header-name="Authorization" 
    failed-validation-httpcode="401" 
    failed-validation-error-message="Unauthorized" 
    require-expiration-time="true" 
    require-scheme="Bearer" 
    require-signed-tokens="true" 
    clock-skew="60">
    <openid-config url="https://login.microsoftonline.com/{tenant}/.well-known/openid-configuration" />
    <audiences>
        <audience>{audience}</audience>
    </audiences>
    <issuers>
        <issuer>https://login.microsoftonline.com/{tenant}/v2.0</issuer>
    </issuers>
    <required-claims>
        <claim name="scope" match="all">
            <value>api.read</value>
        </claim>
    </required-claims>
</validate-jwt>
```

### validate-client-certificate

Validate client certificates.

```xml
<validate-client-certificate 
    validate-revocation="true" 
    validate-trust="true" 
    validate-not-before="true" 
    validate-not-after="true" 
    ignore-error="false">
    <identities>
        <identity thumbprint="certificate-thumbprint" />
        <identity issuer-certificate-id="issuer-cert-id" />
    </identities>
</validate-client-certificate>
```

### check-header

Verify HTTP header existence and value.

```xml
<check-header name="X-API-Key" 
    failed-check-httpcode="401" 
    failed-check-error-message="Missing API key" 
    ignore-case="true">
    <value>expected-value</value>
</check-header>
```

### ip-filter

Filter requests by IP address.

```xml
<ip-filter action="allow">
    <address>10.0.0.1</address>
    <address-range from="10.0.1.0" to="10.0.1.255" />
</ip-filter>

<ip-filter action="forbid">
    <address>192.168.1.100</address>
</ip-filter>
```

---

## Rate Limiting and Quotas

### rate-limit

Limit calls per subscription.

```xml
<rate-limit calls="100" renewal-period="60">
    <api name="*" calls="50">
        <operation name="specific-operation" calls="10" />
    </api>
</rate-limit>
```

### rate-limit-by-key

Limit calls by custom key.

```xml
<rate-limit-by-key calls="100" renewal-period="60" 
    counter-key="@(context.Request.IpAddress)" 
    increment-condition="@(context.Response.StatusCode >= 200 && context.Response.StatusCode < 300)" />
```

### quota

Set usage quota per subscription.

```xml
<quota calls="10000" bandwidth="1048576" renewal-period="86400">
    <api name="*" calls="5000" bandwidth="524288">
        <operation name="expensive-op" calls="100" />
    </api>
</quota>
```

### quota-by-key

Set quota by custom key.

```xml
<quota-by-key calls="10000" bandwidth="1048576" renewal-period="86400" 
    counter-key="@(context.Subscription.Id)" />
```

### limit-concurrency

Limit concurrent requests.

```xml
<limit-concurrency key="@(context.Subscription.Id)" max-count="10">
    <forward-request />
</limit-concurrency>
```

---

## Caching

### cache-lookup / cache-store

Response caching.

```xml
<!-- Inbound -->
<cache-lookup vary-by-developer="true" 
    vary-by-developer-groups="false" 
    caching-type="prefer-external" 
    downstream-caching-type="private" 
    must-revalidate="true" 
    allow-private-response-caching="false">
    <vary-by-header>Accept</vary-by-header>
    <vary-by-query-parameter>version</vary-by-query-parameter>
</cache-lookup>

<!-- Outbound -->
<cache-store duration="3600" />
```

### cache-lookup-value / cache-store-value / cache-remove-value

Key-value caching.

```xml
<!-- Store -->
<cache-store-value key="my-key" value="@(context.Variables["myVar"])" duration="3600" />

<!-- Lookup -->
<cache-lookup-value key="my-key" default-value="not-found" variable-name="cachedValue" />

<!-- Remove -->
<cache-remove-value key="my-key" />
```

---

## Routing

### set-backend-service

Route to a specific backend.

```xml
<!-- By backend ID (recommended for backend pools) -->
<set-backend-service backend-id="my-backend-pool" />

<!-- By URL -->
<set-backend-service base-url="https://api.example.com" />
```

### forward-request

Forward request to backend.

```xml
<forward-request timeout="60" buffer-request-body="true" buffer-response="true" />
```

### rewrite-uri

Rewrite the request URL.

```xml
<rewrite-uri template="/v2/{path}" copy-unmatched-params="true" />
```

### set-url

Set the complete backend URL.

```xml
<set-url>@("https://api.example.com/" + context.Request.MatchedParameters["id"])</set-url>
```

### proxy

Route through HTTP proxy.

```xml
<proxy url="http://proxy.example.com:8080" username="user" password="pass" />
```

---

## Transformation

### set-header

Manage HTTP headers.

```xml
<!-- Add/Override -->
<set-header name="X-Custom-Header" exists-action="override">
    <value>static-value</value>
</set-header>

<!-- Dynamic value -->
<set-header name="X-Request-Id" exists-action="skip">
    <value>@(Guid.NewGuid().ToString())</value>
</set-header>

<!-- Delete -->
<set-header name="X-Internal-Header" exists-action="delete" />

<!-- Multiple values -->
<set-header name="X-Multi" exists-action="append">
    <value>value1</value>
    <value>value2</value>
</set-header>
```

**exists-action values:** `override`, `skip`, `append`, `delete`

### set-query-parameter

Manage query parameters.

```xml
<set-query-parameter name="api-version" exists-action="override">
    <value>2024-01-01</value>
</set-query-parameter>
```

### set-body

Set request/response body.

```xml
<!-- Static body -->
<set-body>{"message": "Hello"}</set-body>

<!-- Dynamic body -->
<set-body>@{
    var body = context.Request.Body.As<JObject>(preserveContent: true);
    body["timestamp"] = DateTime.UtcNow.ToString("o");
    return body.ToString();
}</set-body>

<!-- Liquid template -->
<set-body template="liquid">
{
    "name": "{{body.firstName}} {{body.lastName}}",
    "email": "{{body.email}}"
}
</set-body>
```

### set-variable

Store values for later use.

```xml
<set-variable name="myVar" value="@(context.Request.Headers.GetValueOrDefault("X-Header", ""))" />

<!-- Access later -->
<set-header name="X-Stored" exists-action="override">
    <value>@((string)context.Variables["myVar"])</value>
</set-header>
```

### set-method

Change HTTP method.

```xml
<set-method>POST</set-method>
```

### set-status

Change response status code.

```xml
<set-status code="200" reason="OK" />
```

### json-to-xml / xml-to-json

Convert between formats.

```xml
<json-to-xml apply="always" consider-accept-header="true" parse-date="true" />

<xml-to-json kind="javascript-friendly" apply="always" consider-accept-header="true" />
```

### find-and-replace

String replacement in body.

```xml
<find-and-replace from="old-string" to="new-string" />
```

### xsl-transform

Apply XSLT transformation.

```xml
<xsl-transform>
    <parameter name="param1">@(context.Variables["value"])</parameter>
    <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <!-- XSLT template -->
    </xsl:stylesheet>
</xsl-transform>
```

---

## AI Gateway

### azure-openai-token-limit / llm-token-limit

Limit LLM token consumption.

```xml
<azure-openai-token-limit 
    counter-key="@(context.Subscription.Id)" 
    tokens-per-minute="10000" 
    estimate-prompt-tokens="false" 
    remaining-tokens-variable-name="remainingTokens" />

<!-- Generic LLM version -->
<llm-token-limit 
    counter-key="@(context.Subscription.Id)" 
    tokens-per-minute="10000" 
    estimate-prompt-tokens="false" 
    remaining-tokens-variable-name="remainingTokens" />
```

### azure-openai-emit-token-metric / llm-emit-token-metric

Emit token usage metrics.

```xml
<azure-openai-emit-token-metric namespace="openai">
    <dimension name="Subscription ID" value="@(context.Subscription.Id)" />
    <dimension name="Client IP" value="@(context.Request.IpAddress)" />
    <dimension name="API ID" value="@(context.Api.Id)" />
    <dimension name="Operation ID" value="@(context.Operation.Id)" />
    <dimension name="User ID" value="@(context.Request.Headers.GetValueOrDefault("x-user-id", "N/A"))" />
    <dimension name="Model" value="@(context.Request.Headers.GetValueOrDefault("x-model", "unknown"))" />
</azure-openai-emit-token-metric>
```

### azure-openai-semantic-cache-lookup / azure-openai-semantic-cache-store

Semantic caching for LLM responses.

```xml
<!-- Inbound: Check cache -->
<azure-openai-semantic-cache-lookup 
    score-threshold="0.8" 
    embeddings-backend-id="embeddings-backend" 
    embeddings-backend-auth="system-assigned" />

<!-- Outbound: Store in cache -->
<azure-openai-semantic-cache-store duration="120" />
```

### llm-content-safety

Content safety checks.

```xml
<llm-content-safety backend-id="content-safety-backend" shield-prompt="true">
    <categories output-type="EightSeverityLevels">
        <category name="SelfHarm" threshold="4" />
        <category name="Hate" threshold="4" />
        <category name="Violence" threshold="4" />
        <category name="Sexual" threshold="4" />
    </categories>
    <blocklists>
        <id>custom-blocklist-id</id>
    </blocklists>
</llm-content-safety>
```

---

## Content Validation

### validate-content

Validate request/response body against API schema.

```xml
<validate-content unspecified-content-type-action="prevent" 
    max-size="102400" 
    size-exceeded-action="prevent" 
    errors-variable-name="validationErrors">
    <content type="application/json" validate-as="json" action="prevent" />
</validate-content>
```

### validate-parameters

Validate query/path parameters.

```xml
<validate-parameters specified-parameter-action="prevent" 
    unspecified-parameter-action="ignore" 
    errors-variable-name="paramErrors" />
```

### validate-headers

Validate response headers.

```xml
<validate-headers specified-header-action="ignore" 
    unspecified-header-action="ignore" 
    errors-variable-name="headerErrors" />
```

### validate-status-code

Validate response status codes.

```xml
<validate-status-code unspecified-status-code-action="ignore" 
    errors-variable-name="statusErrors" />
```

---

## Cross-Domain

### cors

Configure CORS.

```xml
<cors allow-credentials="true">
    <allowed-origins>
        <origin>https://app.example.com</origin>
        <origin>https://admin.example.com</origin>
    </allowed-origins>
    <allowed-methods preflight-result-max-age="300">
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>DELETE</method>
        <method>OPTIONS</method>
    </allowed-methods>
    <allowed-headers>
        <header>Content-Type</header>
        <header>Authorization</header>
        <header>X-Requested-With</header>
    </allowed-headers>
    <expose-headers>
        <header>X-Custom-Header</header>
    </expose-headers>
</cors>
```

### jsonp

Add JSONP support.

```xml
<jsonp callback-parameter-name="callback" />
```

---

## Integration and External Communication

### send-request

Send HTTP request and store response.

```xml
<send-request mode="new" response-variable-name="response" timeout="30" ignore-error="false">
    <set-url>https://api.example.com/data</set-url>
    <set-method>POST</set-method>
    <set-header name="Content-Type" exists-action="override">
        <value>application/json</value>
    </set-header>
    <set-header name="Authorization" exists-action="override">
        <value>Bearer token</value>
    </set-header>
    <set-body>@(context.Request.Body.As<string>(preserveContent: true))</set-body>
</send-request>

<!-- Access response -->
<set-variable name="responseBody" value="@(((IResponse)context.Variables["response"]).Body.As<string>())" />
```

### send-one-way-request

Send request without waiting for response.

```xml
<send-one-way-request mode="new">
    <set-url>https://webhook.example.com/notify</set-url>
    <set-method>POST</set-method>
    <set-body>{"event": "request-received"}</set-body>
</send-one-way-request>
```

### log-to-eventhub

Send messages to Event Hub.

```xml
<log-to-eventhub logger-id="my-logger">@{
    return new JObject(
        new JProperty("timestamp", DateTime.UtcNow.ToString("o")),
        new JProperty("requestId", context.RequestId),
        new JProperty("method", context.Request.Method),
        new JProperty("url", context.Request.Url.ToString())
    ).ToString();
}</log-to-eventhub>
```

---

## Logging

### trace

Output trace information.

```xml
<trace source="my-policy" severity="information">
    @("Request ID: " + context.RequestId)
</trace>
```

**Severity levels:** `verbose`, `information`, `error`

### emit-metric

Emit custom metrics.

```xml
<emit-metric name="custom-metric" value="1" namespace="my-namespace">
    <dimension name="API" value="@(context.Api.Name)" />
    <dimension name="Operation" value="@(context.Operation.Name)" />
</emit-metric>
```

---

## Policy Control and Flow

### choose

Conditional policy execution.

```xml
<choose>
    <when condition="@(context.Request.Method == "POST")">
        <!-- Policies for POST requests -->
    </when>
    <when condition="@(context.Request.Method == "GET")">
        <!-- Policies for GET requests -->
    </when>
    <otherwise>
        <!-- Default policies -->
    </otherwise>
</choose>
```

### retry

Retry on failure.

```xml
<retry condition="@(context.Response.StatusCode == 429 || context.Response.StatusCode >= 500)" 
    count="3" 
    interval="1" 
    max-interval="10" 
    delta="1" 
    first-fast-retry="true">
    <forward-request buffer-request-body="true" />
</retry>
```

### return-response

Return custom response immediately.

```xml
<return-response>
    <set-status code="403" reason="Forbidden" />
    <set-header name="Content-Type" exists-action="override">
        <value>application/json</value>
    </set-header>
    <set-body>{"error": "Access denied", "code": "FORBIDDEN"}</set-body>
</return-response>
```

### mock-response

Return mocked response from API definition.

```xml
<mock-response status-code="200" content-type="application/json" />
```

### wait

Wait for multiple async operations.

```xml
<wait for="all">
    <send-request mode="new" response-variable-name="response1" timeout="10">
        <set-url>https://api1.example.com</set-url>
        <set-method>GET</set-method>
    </send-request>
    <send-request mode="new" response-variable-name="response2" timeout="10">
        <set-url>https://api2.example.com</set-url>
        <set-method>GET</set-method>
    </send-request>
</wait>
```

**for values:** `all` (wait for all), `any` (wait for first)

### include-fragment

Include a policy fragment.

```xml
<include-fragment fragment-id="my-reusable-fragment" />
```
