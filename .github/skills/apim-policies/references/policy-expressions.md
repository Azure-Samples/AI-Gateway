# APIM Policy Expressions

Policy expressions use C# syntax to dynamically compute values at runtime. This reference covers syntax, the context variable, and common patterns.

## Table of Contents

- [Syntax](#syntax)
- [Context Variable](#context-variable)
- [Common Expression Patterns](#common-expression-patterns)
- [Working with JSON](#working-with-json)
- [Working with JWT Tokens](#working-with-jwt-tokens)
- [Working with Certificates](#working-with-certificates)
- [Allowed .NET Types](#allowed-net-types)

---

## Syntax

### Single-Statement Expressions

Enclosed in `@(expression)` - returns the result of the expression:

```xml
<set-header name="X-Request-Id" exists-action="override">
    <value>@(Guid.NewGuid().ToString())</value>
</set-header>

<set-variable name="count" value="@((1+1).ToString())" />

<set-variable name="isValid" value="@(context.Request.Headers.ContainsKey("Authorization"))" />
```

### Multi-Statement Expressions

Enclosed in `@{expression}` - must end with a `return` statement:

```xml
<set-body>@{
    var body = context.Request.Body.As<JObject>(preserveContent: true);
    body["timestamp"] = DateTime.UtcNow.ToString("o");
    body["requestId"] = context.RequestId.ToString();
    return body.ToString();
}</set-body>

<set-variable name="authHeader" value="@{
    string[] value;
    if (context.Request.Headers.TryGetValue("Authorization", out value))
    {
        if (value != null && value.Length > 0)
        {
            return value[0].Replace("Bearer ", "");
        }
    }
    return string.Empty;
}" />
```

---

## Context Variable

The `context` variable is implicitly available in every policy expression.

### Request Properties

```csharp
// Request method
context.Request.Method                              // "GET", "POST", etc.

// Request URL
context.Request.Url.Host                            // "api.example.com"
context.Request.Url.Path                            // "/v1/users"
context.Request.Url.Port                            // 443
context.Request.Url.Scheme                          // "https"
context.Request.Url.QueryString                     // "?id=123&name=test"
context.Request.OriginalUrl                         // Original URL before rewrite

// Headers
context.Request.Headers.GetValueOrDefault("name", "default")
context.Request.Headers.ContainsKey("name")
context.Request.Headers["Content-Type"]             // Get header (throws if missing)

// Query parameters
context.Request.Url.Query.GetValueOrDefault("param", "default")
context.Request.Url.Query.ContainsKey("param")

// URL path parameters (from route template)
context.Request.MatchedParameters.GetValueOrDefault("id", "")
context.Request.MatchedParameters.ContainsKey("id")

// Request body
context.Request.Body.As<string>(preserveContent: true)
context.Request.Body.As<JObject>(preserveContent: true)
context.Request.Body.As<byte[]>(preserveContent: true)
context.Request.Body.AsFormUrlEncodedContent(preserveContent: true)

// Client IP
context.Request.IpAddress                           // "192.168.1.100"

// Client certificate
context.Request.Certificate                         // X509Certificate2 or null
```

### Response Properties

```csharp
// Response status
context.Response.StatusCode                         // 200, 404, etc.
context.Response.StatusReason                       // "OK", "Not Found", etc.

// Response headers
context.Response.Headers.GetValueOrDefault("name", "default")
context.Response.Headers.ContainsKey("name")

// Response body
context.Response.Body.As<string>(preserveContent: true)
context.Response.Body.As<JObject>(preserveContent: true)
```

### API and Operation

```csharp
context.Api.Id                                      // API identifier
context.Api.Name                                    // API display name
context.Api.Path                                    // API path prefix
context.Api.Revision                                // API revision
context.Api.Version                                 // API version
context.Api.ServiceUrl                              // Backend service URL

context.Operation.Id                                // Operation identifier
context.Operation.Name                              // Operation display name
context.Operation.Method                            // HTTP method
context.Operation.UrlTemplate                       // URL template pattern
```

### Subscription and User

```csharp
context.Subscription.Id                             // Subscription identifier
context.Subscription.Key                            // Subscription key used
context.Subscription.Name                           // Subscription display name
context.Subscription.PrimaryKey                     // Primary subscription key
context.Subscription.SecondaryKey                   // Secondary subscription key

context.User.Id                                     // User identifier
context.User.Email                                  // User email
context.User.FirstName                              // User first name
context.User.LastName                               // User last name
context.User.Groups                                 // User groups
```

### Product

```csharp
context.Product.Id                                  // Product identifier
context.Product.Name                                // Product display name
context.Product.ApprovalRequired                    // Requires approval
context.Product.SubscriptionRequired                // Requires subscription
context.Product.SubscriptionsLimit                  // Max subscriptions
context.Product.State                               // Published/NotPublished
```

### Deployment and Gateway

```csharp
context.Deployment.ServiceName                      // APIM service name
context.Deployment.ServiceId                        // APIM service ID
context.Deployment.Region                           // Azure region
context.Deployment.Gateway.Id                       // Gateway ID
context.Deployment.Gateway.IsManaged                // Is managed gateway
context.Deployment.Certificates                     // Uploaded certificates
```

### Context Variables

```csharp
// Set in policy
<set-variable name="myVar" value="@("value")" />

// Get in expression
context.Variables.GetValueOrDefault<string>("myVar", "default")
context.Variables.ContainsKey("myVar")
context.Variables["myVar"]                          // Throws if missing
(string)context.Variables["myVar"]                  // Cast to type
```

### Other Context Properties

```csharp
context.RequestId                                   // Unique request GUID
context.Timestamp                                   // Request received time
context.Elapsed                                     // Time elapsed since request
context.LastError                                   // Last error information
context.Tracing                                     // Is tracing enabled
```

---

## Common Expression Patterns

### Working with Headers

```csharp
// Get header with default
context.Request.Headers.GetValueOrDefault("Authorization", "")

// Check header existence
context.Request.Headers.ContainsKey("X-Custom-Header")

// Check header value
context.Request.Headers.GetValueOrDefault("X-API-Version", "").Equals("v2", StringComparison.OrdinalIgnoreCase)

// Get all header values (headers can have multiple values)
string.Join(",", context.Request.Headers.GetValueOrDefault("Accept", new string[0]))
```

### Working with Query Parameters

```csharp
// Get query parameter
context.Request.Url.Query.GetValueOrDefault("filter", "none")

// Check existence
context.Request.Url.Query.ContainsKey("includeDetails")

// Check value
context.Request.Url.Query.GetValueOrDefault("format", "").Equals("json", StringComparison.OrdinalIgnoreCase)
```

### Working with URL Parameters

```csharp
// Get route parameter
context.Request.MatchedParameters.GetValueOrDefault("deployment-id", "")

// Check existence
context.Request.MatchedParameters.ContainsKey("version")

// Example: Get deployment-id or model from URL/body
@{
    var deployment = context.Request.MatchedParameters.ContainsKey("deployment-id") 
        ? context.Request.MatchedParameters["deployment-id"] 
        : string.Empty;
    return deployment;
}
```

### Conditional Logic

```csharp
// Ternary operator
@(context.Request.Method == "POST" ? "write" : "read")

// Null coalescing
@(context.Request.Headers.GetValueOrDefault("X-User", null) ?? "anonymous")

// Complex condition
@(context.Response.StatusCode >= 200 && context.Response.StatusCode < 300)

// String operations
@(context.Request.Url.Path.StartsWith("/api/v2"))
@(context.Api.Name.Contains("internal"))
```

### Date and Time

```csharp
// Current UTC time
@(DateTime.UtcNow.ToString("o"))

// Add time
@(DateTime.UtcNow.AddMinutes(30).ToString("o"))

// Format date
@(DateTime.UtcNow.ToString("yyyy-MM-dd"))

// Unix timestamp
@(DateTimeOffset.UtcNow.ToUnixTimeSeconds())
```

### String Operations

```csharp
// Concatenation
@("Bearer " + (string)context.Variables["token"])

// Format
@($"User: {context.User.Email}, API: {context.Api.Name}")

// Manipulation
@(context.Request.Url.Path.ToLower())
@(context.Request.Headers.GetValueOrDefault("Authorization", "").Replace("Bearer ", ""))
@(context.Api.Name.Substring(0, Math.Min(10, context.Api.Name.Length)))
```

### Generate Values

```csharp
// GUID
@(Guid.NewGuid().ToString())
@(Guid.NewGuid().ToString("N"))  // No hyphens

// Random number
@(new Random().Next(1, 100))

// Hash
@{
    using (var sha256 = SHA256.Create())
    {
        var hash = sha256.ComputeHash(Encoding.UTF8.GetBytes(context.RequestId.ToString()));
        return BitConverter.ToString(hash).Replace("-", "").ToLower();
    }
}
```

---

## Working with JSON

### Read JSON Body

```csharp
// Get entire body as JObject
var body = context.Request.Body.As<JObject>(preserveContent: true);

// Get specific property
var model = context.Request.Body.As<JObject>(preserveContent: true)["model"]?.ToString();

// Using JSONPath
var value = (string)context.Request.Body.As<JObject>(preserveContent: true).SelectToken("data.items[0].name");

// Check property exists
var body = context.Request.Body.As<JObject>(preserveContent: true);
var hasModel = body.ContainsKey("model");
```

### Modify JSON Body

```csharp
@{
    var body = context.Request.Body.As<JObject>(preserveContent: true);
    
    // Add property
    body["timestamp"] = DateTime.UtcNow.ToString("o");
    
    // Modify property
    body["model"] = "gpt-4";
    
    // Remove property
    body.Remove("internalId");
    
    // Add nested object
    body["metadata"] = new JObject(
        new JProperty("requestId", context.RequestId),
        new JProperty("source", "apim")
    );
    
    return body.ToString();
}
```

### Create JSON Response

```csharp
@{
    return new JObject(
        new JProperty("error", new JObject(
            new JProperty("code", "RATE_LIMITED"),
            new JProperty("message", "Too many requests"),
            new JProperty("retryAfter", 60)
        ))
    ).ToString();
}
```

### Access Response Variable Body

```csharp
// After send-request with response-variable-name="response"
var responseBody = ((IResponse)context.Variables["response"]).Body.As<JObject>();
var value = (string)responseBody.SelectToken("data.result");
```

---

## Working with JWT Tokens

### Parse JWT from Header

```csharp
// Get JWT from Authorization header
var jwt = context.Request.Headers.GetValueOrDefault("Authorization", "")
    .Split(' ')
    .Last()
    .AsJwt();

// Access claims
var userId = jwt?.Claims["sub"].FirstOrDefault();
var roles = jwt?.Claims["roles"];
var issuer = jwt?.Issuer;
var audience = jwt?.Audiences.FirstOrDefault();
var expiration = jwt?.ExpirationTime;
```

### Validate and Extract Claims

```csharp
@{
    var authHeader = context.Request.Headers.GetValueOrDefault("Authorization", "");
    if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer "))
    {
        return "anonymous";
    }
    
    var token = authHeader.Substring(7);
    var jwt = token.AsJwt();
    
    if (jwt == null || jwt.ExpirationTime < DateTime.UtcNow)
    {
        return "invalid";
    }
    
    return jwt.Claims["sub"].FirstOrDefault() ?? "unknown";
}
```

### JWT Properties

```csharp
jwt.Algorithm                  // Signing algorithm
jwt.Audiences                  // Token audiences (IEnumerable<string>)
jwt.Claims                     // All claims (IReadOnlyDictionary<string, string[]>)
jwt.ExpirationTime             // Expiration (DateTime?)
jwt.Id                         // Token ID (jti claim)
jwt.Issuer                     // Token issuer
jwt.IssuedAt                   // Issue time (DateTime?)
jwt.NotBefore                  // Not valid before (DateTime?)
jwt.Subject                    // Subject (sub claim)
jwt.Type                       // Token type
```

---

## Working with Certificates

### Client Certificate Validation

```csharp
// Check certificate exists
context.Request.Certificate != null

// Validate certificate
context.Request.Certificate.Verify()  // Full validation including revocation
context.Request.Certificate.VerifyNoRevocation()  // Without revocation check

// Check issuer
context.Request.Certificate.Issuer == "CN=MyCA, O=MyOrg"

// Check subject
context.Request.Certificate.SubjectName.Name == "CN=client.example.com"

// Check thumbprint
context.Request.Certificate.Thumbprint == "THUMBPRINT_IN_UPPERCASE"

// Check if certificate is uploaded to APIM
context.Deployment.Certificates.Any(c => c.Value.Thumbprint == context.Request.Certificate.Thumbprint)
```

### Certificate Properties

```csharp
context.Request.Certificate.Thumbprint
context.Request.Certificate.Subject
context.Request.Certificate.SubjectName.Name
context.Request.Certificate.Issuer
context.Request.Certificate.NotBefore
context.Request.Certificate.NotAfter
context.Request.Certificate.SerialNumber
```

---

## Allowed .NET Types

Policy expressions can use these .NET Framework types:

### Core Types
- `System.String`, `System.Char`, `System.Boolean`
- `System.Byte`, `System.Int16`, `System.Int32`, `System.Int64`
- `System.Single`, `System.Double`, `System.Decimal`
- `System.DateTime`, `System.DateTimeOffset`, `System.TimeSpan`, `System.TimeZoneInfo`
- `System.Guid`, `System.Uri`, `System.Enum`, `System.Tuple`

### Collections
- `System.Array`, `System.Collections.Generic.Dictionary<TKey, TValue>`
- `System.Collections.Generic.List<T>`, `System.Collections.Generic.HashSet<T>`
- `System.Collections.Generic.Queue<T>`, `System.Collections.Generic.Stack<T>`
- `System.Linq.Enumerable` (all LINQ methods)

### Text and Regex
- `System.Text.Encoding`, `System.Text.StringBuilder`
- `System.Text.RegularExpressions.Regex`, `System.Text.RegularExpressions.Match`

### JSON (Newtonsoft.Json)
- `Newtonsoft.Json.JsonConvert`
- `Newtonsoft.Json.Linq.JObject`, `JArray`, `JToken`, `JProperty`, `JValue`

### XML
- `System.Xml.Linq.XDocument`, `XElement`, `XAttribute`, `XNode`

### Cryptography
- `System.Security.Cryptography.SHA256`, `SHA384`, `SHA512`
- `System.Security.Cryptography.HMACSHA256`, `HMACSHA384`, `HMACSHA512`
- `System.Security.Cryptography.RSA`
- `System.Security.Cryptography.X509Certificates.X509Certificate2`

### Other
- `System.Convert`, `System.Math`, `System.Random`
- `System.Net.IPAddress`, `System.Net.WebUtility`
- `System.IO.StringReader`, `System.IO.StringWriter`
