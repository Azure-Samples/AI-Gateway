---
name: Microsoft Web IQ Usage Tracking and MCP
architectureDiagram: ""
categories:
  - Knowledge & Tools
  - Platform Capabilities
services:
  - Microsoft Web IQ
  - Azure API Management
  - Azure AI Content Safety
  - Application Insights
  - Log Analytics
shortDescription: Track Microsoft Web IQ REST and MCP usage, block Browse, and moderate response text at the APIM gateway.
detailedDescription: Route Microsoft Web IQ Web Search and MCP requests through Azure API Management. Clients supply an APIM subscription key for consumer attribution. In Entra mode, APIM acquires the Web IQ token with its system-assigned managed identity; API-key mode forwards the caller's Web IQ key. APIM blocks Browse and analyzes buffered response text with the four standard Content Safety categories using its system-assigned managed identity. Response headers expose moderation scores, and Application Insights metrics track usage, moderation outcomes, gateway errors, and latency.
tags:
  - Web grounding
  - Usage tracking
  - Custom metrics
  - Model Context Protocol
authors: []
---

# APIM ❤️ Microsoft Web IQ

## [Microsoft Web IQ Usage Tracking and MCP lab](web-iq.ipynb)

This lab places Azure API Management (APIM) in front of the [Microsoft Web IQ](https://webiq.microsoft.ai/documentation/overview/) REST and [Model Context Protocol (MCP)](https://webiq.microsoft.ai/documentation/mcp/) endpoints. It demonstrates how a shared gateway can attribute web-grounding usage to individual consumers, enforce an operation restriction, and expose usage and latency metrics through Application Insights.

Each client supplies an **APIM subscription key** identifying the consuming team. Set `WEBIQ_AUTH_MODE=entra` before deployment to have APIM acquire and attach the Web IQ access token with its **system-assigned managed identity**. Clients do not acquire or supply Web IQ Entra tokens. The default `apikey` mode additionally requires a caller-provided Web IQ key in `x-apikey`.

APIM uses its **system-assigned managed identity** to analyze upstream response text with Azure AI Content Safety. The example enables the four standard text categories—Hate, Sexual, Violence, and SelfHarm—and adds moderation telemetry to response bodies and headers. Category scores do not automatically block flagged content.

Start with [web-iq.ipynb](web-iq.ipynb) to deploy the infrastructure and test REST and MCP. Then optionally use [web-iq-mcp-responses.ipynb](web-iq-mcp-responses.ipynb) to let an Azure OpenAI model call the gateway's remote MCP endpoint.

### What you'll learn

- Separate APIM consumer identification from Web IQ authentication.
- Compare usage across the `research-team` and `support-team` APIM subscriptions.
- Use APIM managed identity for Web IQ Entra authentication, or forward caller-provided Web IQ API keys.
- Discover and invoke Web IQ tools over streamable HTTP MCP.
- Block the Browse REST operation and MCP tool before either reaches Web IQ.
- Query requests, blocked calls, response codes, gateway errors, and latency by subscription and operation.
- Inspect standard text moderation scores on Web IQ responses without supplying a Content Safety key.
- Validate remote MCP calls made by the Azure OpenAI Responses API.

### Architecture

The diagram shows the deployed flow when `webIqAuthMode=entra`: APIM managed identity acquires the Web IQ access token. In `apikey` mode, APIM forwards the caller-provided `x-apikey` instead. Content Safety is shown as an **optional architecture step**; the deployed example always enables response text moderation, using APIM's system-assigned identity for Content Safety.

```mermaid
flowchart LR
    Client[REST or MCP client]
    Entra[Microsoft Entra ID]
    subgraph Gateway[Azure API Management]
        Subscription[Validate APIM subscription key]
        Inspect[Identify operation and MCP tool]
        Block[Return BrowseOperationBlocked: 403]
        Auth[APIM managed identity]
        Forward[Set Web IQ bearer token]
        Moderate[Optional: moderate response text]
        Telemetry[Add Content Safety results and headers]
    end
    Client -->|APIM subscription key| Subscription
    Subscription -->|Strip APIM credential| Inspect
    Inspect -->|Restricted WebIQ ex. Browse| Block
    Inspect -->|Other requests| Auth
    Auth -.->|Request Web IQ access token| Entra
    Entra -.->|Web IQ access token| Auth
    Auth --> Forward
    Forward -->|Bearer token + REST or MCP request| WebIQ[Microsoft Web IQ v3]
    WebIQ -->|Buffered response| Moderate
    Moderate -.->|APIM system managed identity| Safety[Azure AI Content Safety]
    Safety -.->|Hate, Sexual, Violence, SelfHarm scores| Moderate
    Moderate --> Telemetry
    Telemetry -->|Response and moderation telemetry| Client
    Inspect --> Logs[Log Analytics workspace]
```

The deployment creates an APIM instance, two consumer subscriptions, a Web IQ backend and API, a Content Safety S0 resource, an Application Insights resource with dimensional custom metrics enabled, and a Log Analytics workspace. It assigns APIM's system identity the **Cognitive Services User** role on the Content Safety resource and disables key authentication there. Web IQ is an external service; the deployment does not provision a Web IQ account or key. The optional Responses API notebook also uses an existing Azure OpenAI deployment.

### Folder contents

| File | Purpose |
| --- | --- |
| [web-iq.ipynb](web-iq.ipynb) | Deploy the lab, test Web Search, authenticate with APIM managed identity in Entra mode, exercise MCP, and query telemetry. |
| [web-iq-mcp-responses.ipynb](web-iq-mcp-responses.ipynb) | Test Web IQ remote MCP through an existing Azure OpenAI Responses API deployment. |
| [main.bicep](main.bicep) | Compose shared infrastructure modules and configure the backend, API, policy, and diagnostics. |
| [openapi.json](openapi.json) | Define Web Search, Browse, and MCP operations and their stable operation IDs. |
| [policy.xml](policy.xml) | Handle credentials, classify MCP traffic, block Browse, forward requests, and emit metrics. |
| [content-safety-outbound.xml](content-safety-outbound.xml) | Analyze response text with the standard categories and attach moderation telemetry. |
| [content_safety.py](content_safety.py) | Extract moderation telemetry from REST/MCP results and format notebook table rows. |
| [clean-up-resources.ipynb](clean-up-resources.ipynb) | Remove the lab resource group using the shared cleanup helper. |

The notebooks use [shared/utils.py](../../shared/utils.py) and the repository's [Python environment](../../pyproject.toml). The deployment notebook generates a local `params.json`. An optional `.env` stores local configuration. Both filenames are ignored by Git.

### Prerequisites

- Access to [Microsoft Web IQ](https://webiq.microsoft.ai/documentation/overview/) and either an API key or Entra authentication enabled in Web IQ Profile Management. The notebooks describe Web IQ as a limited-access service; confirm your account can use Web Search and the MCP `web` tool.
- [Python 3.12 or later](https://www.python.org/) and [uv](https://docs.astral.sh/uv/).
- [VS Code](https://code.visualstudio.com/) with the [Jupyter extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter), or an equivalent notebook environment.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), authenticated to the intended tenant and subscription.
- An Azure subscription with the lab's documented Contributor + RBAC Administrator, or Owner, permissions, and availability for the selected APIM SKU and region.

For Web IQ Entra mode, bind the deployed APIM managed identity’s **Application (client) ID** in Web IQ Profile Management before sending requests. The notebook does not need a Web IQ client secret or token. For the Responses API notebook, you need an existing Azure OpenAI deployment supporting Responses and remote MCP, plus the **Cognitive Services OpenAI User** role for the identity used by `DefaultAzureCredential`.

### 🚀 Get started

#### 1. Prepare the environment

From the repository root (`C:\repo\AI-Gateway` on Windows or `/mnt/c/repo/AI-Gateway` in WSL), run:

```bash
uv sync
az login
az account set --subscription "<subscription-id>"
az account show
```

Open [web-iq.ipynb](web-iq.ipynb) and select the repository's `.venv` Python interpreter as the kernel: `.venv/bin/python` on Linux/WSL or `.venv\Scripts\python.exe` on Windows. Run its cells with `labs/web-iq` as the working directory so relative imports and Bicep paths resolve correctly.

The root environment includes `requests`, `msal`, `python-dotenv`, `pandas`, Azure identity libraries, the OpenAI SDK, and the pinned `mcp==1.21.2` package. This lab has no separate dependency installation.

#### 2. Select Web IQ authentication

For APIM managed-identity authentication, create or update the ignored `labs/web-iq/.env` with:

```dotenv
WEBIQ_AUTH_MODE="entra"
```

For caller-provided API-key authentication, use:

```dotenv
WEBIQ_AUTH_MODE="apikey"
WEBIQ_API_KEY="<web-iq-api-key>"
```

The initialization cell loads dotenv settings. `apikey` is the default when `WEBIQ_AUTH_MODE` is absent; only that mode prompts with `getpass` if `WEBIQ_API_KEY` is missing. Entra mode needs no Web IQ credential in the notebook.

The deployment parameters contain no Web IQ credential. Keep `.env` local; if you use the interactive prompt, the key is held in the notebook process without being written to a configuration file.

#### 3. Review the deployment settings

Edit the initialization cell before deploying if you need different names, a different region, or another supported SKU.

| Notebook setting | Default | Purpose |
| --- | --- | --- |
| `deployment_name` | `web-iq` | Azure resource-group deployment name. |
| `resource_group_name` | `lab-web-iq` | Resource group created for the lab. |
| `resource_group_location` | `westus2` | Region for the deployed resources. |
| `apim_sku` | `Basicv2` | APIM pricing tier. Check regional availability before changing it. |
| `web_iq_api_path` | `web-iq` | Gateway URL prefix for all operations. |
| `web_iq_auth_mode` | `apikey` | Read from `WEBIQ_AUTH_MODE`; use `entra` for APIM managed identity. |
| `apim_subscriptions_config` | `research-team`, `support-team` | Consumer subscriptions used in the sample requests and metrics. |

The Bicep parameters are `apimSku`, `apimSubscriptionsConfig`, `webIqApiPath`, `webIqAuthMode`, `webIqServiceUrl`, and `contentSafetyLocation`. `webIqAuthMode` accepts `apikey` (default) or `entra`. Content Safety defaults to the resource group's region; choose a supported region if needed. The upstream service URL defaults to `https://api.microsoft.ai/v3`. The notebook supplies the first four parameters; direct Bicep deployments must supply subscription configuration to create the two sample consumers, because the template's array default is empty.

APIM, monitoring, and Content Safety usage incur Azure charges. Each analyzed text chunk makes a Content Safety API call. Web IQ usage and the optional Azure OpenAI calls may incur separate charges under your service agreements.

#### 4. Deploy and run the examples

Run the main notebook in order. It verifies the active Azure subscription, creates the resource group, writes `params.json`, and deploys [main.bicep](main.bicep). Wait for the deployment to complete before running the request cells.

The output retrieval cell loads the gateway URL, Application Insights name, API path, authentication mode, and APIM subscription keys. In Entra mode, it also prints the command to resolve the APIM managed identity’s client ID; complete the [Web IQ binding](#web-iq-entra-id-authentication-with-apim-managed-identity) before running request cells. It displays the subscription keys masked to their final four characters. For use in another client, retrieve a key from the APIM resource's **Subscriptions** page. APIM subscription IDs used in telemetry are resolved from those keys; clients do not send the raw subscription ID.

The remaining cells send Web Search requests for both teams using the deployed authentication mode, verify managed identity in Entra mode, discover MCP tools, invoke `web`, attempt blocked Browse calls, and query telemetry. If you change the sample subscription names or remove a subscription, also update the workload names and subscription indexes in the example cells.

### Gateway endpoints and authentication

With the default API path, the client base URL is `https://<apim-name>.azure-api.net/web-iq`.

| Method and path | Operation ID | Behavior |
| --- | --- | --- |
| `POST /web-iq/search/web` | `search-web` | Forward Web Search to Web IQ. |
| `POST /web-iq/browse` | `browse-url` | Return the policy's structured `403 Forbidden`. |
| `POST /web-iq/mcp` | `mcp-post` | Forward MCP messages, except `tools/call` for `browse`. |
| `GET /web-iq/mcp` | `mcp-get` | Return `405`; the optional long-lived event stream is disabled to support complete response moderation. |
| `DELETE /web-iq/mcp` | `mcp-delete` | Proxy session termination when supported upstream. |

Every operation requires a valid APIM subscription. The deployed `webIqAuthMode` selects upstream authentication; caller headers cannot switch the gateway mode:

| Purpose | Header | Policy behavior |
| --- | --- | --- |
| Identify the consumer | `Ocp-Apim-Subscription-Key: <apim-key>` | APIM validates the key and the policy removes it before forwarding. The API also accepts the `subscription-key` query parameter, which the policy removes. |
| Web IQ authentication with `webIqAuthMode=apikey` | `x-apikey: <web-iq-key>` | Forward the Web IQ key and remove any caller `Authorization` header. |
| Web IQ authentication with `webIqAuthMode=entra` | No additional client credential | Remove `x-apikey`, acquire a token with APIM managed identity, and override `Authorization` with that token. |

Web IQ validates the credential APIM sends upstream. In `apikey` mode, an allowed request missing `x-apikey` receives `401` with `errorCode: WebIqAuthenticationRequired`; a caller bearer token does not satisfy that requirement. In `entra` mode, APIM acquires its own token with `ignore-error="false"`, so token acquisition failure stops the request. Browse is rejected before upstream authentication, so a valid APIM subscription is sufficient to exercise the Browse denial.

#### REST Web Search example

After deploying Entra mode and binding the managed identity, set `APIM_GATEWAY_URL` to the gateway origin and `APIM_SUBSCRIPTION_KEY` to a consumer key. This Bash example uses the default API path and sends no Web IQ credential:

```bash
curl --request POST "${APIM_GATEWAY_URL%/}/web-iq/search/web" \
  --header "Ocp-Apim-Subscription-Key: ${APIM_SUBSCRIPTION_KEY}" \
  --header "Content-Type: application/json" \
  --data '{"query":"What is Azure API Management?","maxResults":3,"maxLength":3000,"contentFormat":"markdown"}'
```

For a gateway deployed in `apikey` mode, also pass `--header "x-apikey: ${WEBIQ_API_KEY}"`.

A successful response follows the [Web Response schema](https://webiq.microsoft.ai/documentation/api-reference/web/#web-response). The notebook summarizes `traceId`, `querySignals`, instrumentation availability, and `webResults` entries, including titles, URLs, content previews, timestamps, language, and content metadata. The policy adds an `x-apim-request-id` response header for gateway correlation and the Content Safety headers described below. Add `--include` to the curl command to display these headers.

### Standard response text moderation

Every upstream response with text passes through `POST /contentsafety/text:analyze?api-version=2024-09-01` before APIM releases it. This applies to REST, MCP discovery and tool results, session responses, and upstream error bodies. APIM authenticates the separate moderation request with its system-assigned managed identity and the `https://cognitiveservices.azure.com` audience. The selected Web IQ credential is used only for the Web IQ request; Content Safety obtains its own token.

Only the four standard text categories are enabled. There are no custom blocklists, Prompt Shields, image moderation, or custom blocking thresholds. The API uses `FourSeverityLevels`: **0** (safe), **2** (low), **4** (medium), and **6** (high). A successfully analyzed response retains its original status and result data, including flagged content, with added moderation telemetry. The scores are telemetry for consumers to interpret, not a guarantee that content is safe.

REST JSON objects include a top-level `contentSafety` object with `status`, `scores`, `chunks`, `latencyMs`, and `requestId`. MCP results include the same object in `result._meta.contentSafety`. Tool results also include it in `structuredContent` and the first text content block, so clients that expose only structured content or only the first text block retain the scores. JSON tool text gets an added `contentSafety` property; plain tool text retains its original text followed by the telemetry JSON. JSON-RPC errors include telemetry in `error.data.contentSafety`. Finite SSE responses preserve event IDs, event types, and original result data while adding telemetry to JSON data frames. Plain-text and empty responses retain header telemetry only.

Both notebooks display a **Content Safety results table** with one row per request/tool call and separate **Hate**, **Sexual**, **Violence**, and **SelfHarm** columns. The Responses notebook reads actual `mcp_call.output`; the model's final answer may omit this telemetry. After updating the policy, rerun the request/tool-invocation cell followed by the results cell. Saved responses from before the update cannot contain the new body fields. Missing scores display as missing values, not zero.

| Response header | Meaning |
| --- | --- |
| `x-content-safety-status` | `analyzed`, `no-text`, `not-applicable`, `error`, `response-too-large`, or `unsupported-encoding`. |
| `x-content-safety-scores` | Compact JSON with the highest severity across chunks for `Hate`, `Sexual`, `Violence`, and `SelfHarm`. Present only after a complete, successful analysis. |
| `x-content-safety-chunks` | Number of Content Safety requests attempted for this response. |
| `x-content-safety-latency-ms` | Time spent extracting and analyzing the response text. |

For example, a completely analyzed response can include:

```http
x-content-safety-status: analyzed
x-content-safety-scores: {"Hate":0,"Sexual":0,"Violence":2,"SelfHarm":0}
x-content-safety-chunks: 1
x-content-safety-latency-ms: 185
```

The policy extracts JSON string values, decodes JSON embedded in MCP text, and parses the data frames of finite SSE responses. It analyzes plain text directly. Text is split into chunks of at most 10,000 UTF-16 code units (within the API's 10,000-code-point limit), with 200 units of overlap and intact surrogate pairs. The lab accepts up to 100,000 extracted units per response; larger responses return `502` with `ContentSafetyAnalysisFailed` instead of being truncated. Analysis failures, incomplete category results, or unexpected compressed responses also return `502` without the upstream body. Check the status header and gateway telemetry, then retry or reduce the result size.

Empty acknowledgments or responses containing no text report `no-text` and make no moderation call. Gateway-generated Browse denials, missing-credential errors, and MCP GET rejections report `not-applicable`, because there is no upstream content to analyze. Unexpected policy errors during moderation report `error`; chunk and latency headers may be absent on that error path.

Response text is sent to the deployed Content Safety resource for analysis. Application Insights custom metrics contain only status, timing, and the existing bounded dimensions; they do not contain the analyzed text. Redeploy `main.bicep` to install the resource, role assignment, fragment, and updated API policy. New managed-identity role assignments may need several minutes to propagate.

#### Web IQ Entra ID authentication with APIM managed identity

Set `WEBIQ_AUTH_MODE="entra"`, rerun initialization, and redeploy. This passes `webIqAuthMode=entra` to Bicep and installs the Entra branch of [policy.xml](policy.xml):

```xml
<authentication-managed-identity resource="https://api.microsoft.ai" output-token-variable-name="web-iq-access-token" ignore-error="false" />
<set-header name="Authorization" exists-action="override">
    <value>@("Bearer " + (string)context.Variables["web-iq-access-token"])</value>
</set-header>
```

The [APIM policy examples](https://learn.microsoft.com/en-us/azure/api-management/authentication-managed-identity-policy#examples) show this token acquisition and header pattern. Omitting `client-id` selects APIM’s system-assigned identity. APIM caches the token until it expires. [Web IQ authentication](https://learn.microsoft.com/en-us/web-iq/get-started/authentication) specifies scope `https://api.microsoft.ai/.default`; the policy takes resource `https://api.microsoft.ai` without `/.default`.

After deployment, resolve the **Application (client) ID** from the `apimManagedIdentityPrincipalId` output:

```bash
az ad sp show --id "<apimManagedIdentityPrincipalId>" --query appId --output tsv
```

Bind the returned client ID in [Web IQ Profile Management](https://webiq.microsoft.ai/profiles) under **Application (Client) IDs**. Do not bind the principal/object ID. If the tab is unavailable, contact your Microsoft representative to enable Entra authentication. Allow up to one minute for the profile binding to synchronize before sending requests.

Clients then send only the APIM subscription key for both REST and MCP. No `WEBIQ_TENANT_ID`, `WEBIQ_CLIENT_ID`, `WEBIQ_CLIENT_SECRET`, or client-supplied Web IQ bearer token is needed. Changing the local mode requires redeploying the gateway policy as well.

When the identity is bound to several Web IQ AppIDs, append `?APPID=<web-iq-appid>` to the REST or MCP endpoint URL to select one. `APPID` is the Web IQ AppID, not the identity’s client ID. Omit `APPID` from API-key requests, as Web IQ rejects that combination.

### MCP discovery and Browse enforcement

MCP clients use the same search arguments and authentication mode as REST. In Entra mode they send only their APIM subscription key, and APIM supplies the Web IQ bearer token. APIM uses `buffer-response="true"` and reads the complete response before moderation, so finite SSE messages from `POST /mcp` retain their framing but arrive after analysis. The optional long-lived `GET /mcp` stream returns `405 Method Not Allowed` with `Allow: POST, DELETE`, as permitted by the MCP transport. Use clients that support this mode. This example does not provide live server-initiated notifications or incremental delivery. Tool availability depends on the Web IQ account.

For `POST /mcp`, the policy inspects the JSON-RPC method and `params.name` while preserving the request body. It labels tool calls with one of `web`, `videos`, `browse`, `news`, `images`, or `unknown`. Non-tool messages and unparseable bodies receive the `protocol` label. Other operations receive `N/A`. This classification bounds the metric values; it is not a tool allowlist.

The policy blocks REST operation `browse-url` and MCP `tools/call` requests whose tool name is `browse`. Both receive HTTP `403` with:

```json
{
  "errorCode": "BrowseOperationBlocked",
  "errorCategory": "UserError",
  "userMessage": "The Browse operation and MCP tool are disabled by the API Management policy."
}
```

Web IQ may still advertise `browse` in `tools/list`: APIM blocks invocation without rewriting discovery results. The MCP client can surface the denial as a transport exception because the response is an HTTP error with the gateway's JSON body. Verify the `403` and error code when diagnosing a negative test; an unrelated connection or authentication failure does not demonstrate Browse enforcement.

### Azure OpenAI Responses API MCP test flow

The optional [Responses API notebook](web-iq-mcp-responses.ipynb) invokes a model that connects to Web IQ through APIM. **The Azure OpenAI service makes the remote MCP connection**, so the gateway endpoint must be publicly reachable over HTTPS with TLS 1.2 or later.

```mermaid
flowchart LR
    Notebook[Test notebook]
    Entra[Microsoft Entra ID]
    Responses[Azure OpenAI Responses API]
    Gateway[APIM Web IQ MCP endpoint]
    WebIQ[Microsoft Web IQ]
    Safety[Optional: Content Safety text moderation]
    Notebook -.->|DefaultAzureCredential| Entra
    Entra -.->|Azure OpenAI access token| Notebook
    Notebook -->|responses.create with MCP configuration| Responses
    Responses -->|APIM subscription key| Gateway
    Gateway -.->|APIM managed identity requests Web IQ token| Entra
    Entra -.->|Web IQ access token| Gateway
    Gateway -->|Web IQ bearer token for allowed calls| WebIQ
    WebIQ -->|Tool results| Gateway
    Gateway -.->|Buffered response text; APIM system managed identity| Safety
    Safety -.->|Hate, Sexual, Violence, SelfHarm scores| Gateway
    Gateway -->|Tool results with safety telemetry, or gateway error| Responses
    Responses -->|Answer and MCP events| Notebook
```

This diagram shows Entra mode. In `apikey` mode, the MCP client also supplies `x-apikey` and APIM forwards it. Content Safety is an optional step in this architecture diagram and is always enabled in the deployed example. Safety telemetry is included in MCP tool content so the Responses notebook can display it from `mcp_call.output`, even when transport headers are not exposed.

Add these connection strings to `labs/web-iq/.env`, substituting the deployed gateway and your existing Azure OpenAI resource:

```dotenv
WEBIQ_AUTH_MODE="entra"
AZURE_OPENAI_CONNECTION_STRING="Endpoint=https://<resource>.openai.azure.com;Deployment=<deployment-name>"
WEB_IQ_MCP_CONNECTION_STRING="Endpoint=https://<apim-name>.azure-api.net/web-iq/mcp;Ocp-Apim-Subscription-Key=<apim-subscription-key>"
```

`Deployment` is the Azure OpenAI deployment name. Set `WEBIQ_AUTH_MODE` to match the deployed gateway. Entra mode requires only `Ocp-Apim-Subscription-Key` in the MCP connection string. For `apikey` mode, also add `;x-apikey=<web-iq-key>` to that connection string. Setting `WEBIQ_API_KEY` alone does not populate this connection string.

Before running the positive `web` test, review its `responses.create` call: **the current cell hard-codes `model="gpt-5.4-nano"`**. Replace that value with `model=azure_openai_model` to use the deployment configured in `.env`, or ensure a compatible deployment with that exact name exists. The later Browse test already uses `azure_openai_model`.

Run the notebook in order. It authenticates to Azure OpenAI through `DefaultAzureCredential` with scope `https://ai.azure.com/.default`, normalizes the endpoint to `/openai/v1/`, and configures the remote MCP tool with `allowed_tools=['web']`, `tool_choice='required'`, and `require_approval='never'` for this test. A successful run returns answer text and a `web` MCP call without an error, then prints `PASS: Azure OpenAI called the Web IQ web tool through APIM.`

The final cell exposes only `browse` and expects an error. Inspect the underlying failure and gateway telemetry to distinguish the intended Browse rejection from authentication, discovery, or connectivity failures.

### Usage metrics and diagnostics

All policy metrics use the `web-iq` namespace. Application Insights is configured with `WithDimensions`, API diagnostic sampling is set to 100%, request and response body capture is set to zero bytes, header capture lists are empty, and client-IP logging is disabled for these API diagnostics.

| Metric | Recorded value and stage |
| --- | --- |
| `Web IQ Requests` | `1` when the inbound policy reaches the request metric, before Browse and upstream-credential checks. |
| `Web IQ Blocked Requests` | `1` when the policy rejects REST Browse or the MCP `browse` tool. |
| `Web IQ Responses` | `1` when a request reaches the outbound policy, with its HTTP status. |
| `Web IQ Latency` | `context.Elapsed.TotalMilliseconds` at the outbound policy, with the HTTP status. |
| `Web IQ Gateway Errors` | `1` when the gateway executes the `on-error` policy. |
| `Web IQ Content Safety Responses` | `1` per outbound moderation outcome, grouped by `Content Safety Status`. |
| `Web IQ Content Safety Latency` | Milliseconds spent extracting and moderating response text. |

Requests and blocked calls carry `Subscription ID`, `Operation ID`, `Authentication`, and `MCP Tool` dimensions. Responses and latency add `Status Code`. Gateway errors include only `Subscription ID`, `Operation ID`, and `MCP Tool`. Authentication labels are `API key`, `Entra ID`, and `Missing`. `Entra ID` identifies the configured APIM managed-identity path; `Missing` means API-key mode received no key. Labels do not establish successful upstream validation.

The custom metrics exclude search text, target URLs, response content, tokens, subscription keys, and client IPs. The API's diagnostics configuration limits captured content, but this is not a guarantee about every Azure resource log, deployment output, or saved notebook output. The notebook intentionally displays search results, and deployment outputs contain APIM subscription keys.

Interpret the metrics according to their policy stage:

- An inbound `return-response`, including the Browse `403` or missing-credential `401`, skips the outbound response and latency metrics. Use the blocked metric for Browse denials.
- One MCP tool invocation can involve several HTTP requests for initialization, discovery, tool execution, and session management. Filter by `MCP Tool = web` when measuring Web Search tool calls.
- Latency includes buffering and Content Safety processing at the outbound policy. It does not measure the full duration of an Azure OpenAI answer.
- Gateway errors are separate from HTTP error responses returned by Web IQ. Inspect response status metrics for upstream failures.

#### Query request volume and blocked calls

In the deployed Application Insights resource, open **Logs** and run:

```kusto
customMetrics
| where timestamp > ago(1h)
| where name in ('Web IQ Requests', 'Web IQ Blocked Requests')
| extend SubscriptionId = tostring(customDimensions['Subscription ID']),
         OperationId = tostring(customDimensions['Operation ID']),
         Authentication = tostring(customDimensions['Authentication']),
         McpTool = tostring(customDimensions['MCP Tool'])
| summarize Requests = sumif(value, name == 'Web IQ Requests'),
            BlockedRequests = sumif(value, name == 'Web IQ Blocked Requests')
    by SubscriptionId, OperationId, Authentication, McpTool
| order by Requests desc
```

The main notebook uses the installed `az` command and its signed-in account to query the Application Insights API through `az rest`. KQL is sent in a temporary JSON file, preserving quotes, comments, and line breaks across Windows, Linux, and macOS. The notebook kernel does not need the `azure.cli` Python package or the Application Insights CLI extension. Separate queries report latency and Content Safety outcomes. Query failures raise an error instead of appearing as an empty table. Custom metrics may take several minutes to arrive; the helper's `PT1H` timespan and the queries' `ago(1h)` filters cover the last hour—update both for an older range.

For a chart, open **Metrics**, select the `web-iq` custom namespace and a metric, and split by the available dimensions. These metrics describe gateway consumption. Web IQ's [citation and click instrumentation](https://webiq.microsoft.ai/documentation/instrumentation/) is a separate feature.

### Troubleshooting

| Symptom | What to check |
| --- | --- |
| `ModuleNotFoundError`, MCP import errors, or missing shared utilities | Run `uv sync` at the repository root, select its `.venv` kernel, restart the kernel, and use `labs/web-iq` as the notebook working directory. |
| Azure deployment fails | Check the active subscription, resource permissions, selected region/SKU availability, and the deployment error shown by Azure CLI. |
| APIM rejects the subscription credential | Use an active APIM subscription key in `Ocp-Apim-Subscription-Key`, rather than a subscription ID, Azure subscription ID, or Web IQ key. |
| `401` with `WebIqAuthenticationRequired` | In API-key mode, send `x-apikey` with the APIM subscription key. For managed identity, set `WEBIQ_AUTH_MODE=entra` and redeploy. |
| Upstream authentication failure | Verify Web IQ account access and the API key, or the APIM managed identity client-ID binding and `https://api.microsoft.ai` audience. Allow for binding propagation. For multiple Web IQ AppIDs, supply `APPID`; omit it in API-key mode. |
| MCP discovery does not expose `web` | Check which tools the Web IQ account enables and that the gateway URL ends in the configured API path plus `/mcp`. |
| Browse appears in discovery but invocation fails | This is expected when the failure is the policy's `403` with `BrowseOperationBlocked`; discovery results are forwarded unchanged. |
| Responses API reports a missing model/deployment | Review the positive test's hard-coded model and use the deployment name from `AZURE_OPENAI_CONNECTION_STRING`. |
| Responses API cannot reach MCP | Check public HTTPS reachability from Azure OpenAI and the APIM subscription header plus `x-apikey` in API-key mode in `WEB_IQ_MCP_CONNECTION_STRING`. Local notebook connectivity alone is insufficient. |
| Azure OpenAI authentication fails after a long pause | Check the role assignment and selected identity, then rerun the client-creation cell to acquire a fresh token; the current notebook passes a token string to the SDK. |
| Usage query fails with `No module named azure.cli` | Rerun the updated query-helper cell. It calls the installed `az` command independently of the notebook's Python environment. Ensure Azure CLI is on the kernel's PATH and authenticated with `az login`. |
| Usage query fails with `BadArgumentError` on Windows | Rerun the updated query-helper cell. It sends KQL through a JSON file, avoiding the Windows shell quoting and multiline argument problems of the earlier helper. |
| Usage queries are empty | Allow for ingestion delay, check the Application Insights resource and time range, and verify deployment of the logger, dimensional metrics, and API diagnostics. |
| `502` with `ContentSafetyAnalysisFailed` | Inspect `x-content-safety-status`. Check Content Safety availability/quota and APIM's resource-scoped Cognitive Services User role; allow for role propagation. For `response-too-large`, reduce result count or length. The original response is withheld when analysis cannot complete. |
| MCP GET returns `405`, or POST results arrive all at once | Expected for this example: complete response moderation buffers POST results and disables the optional long-lived GET stream. |

### 🗑️ Clean up resources

Run [clean-up-resources.ipynb](clean-up-resources.ipynb) from this folder when finished. Its defaults target deployment `web-iq` in resource group `lab-web-iq`; update both values if you changed them during setup.

The shared cleanup helper deletes and purges the lab APIM instance and removes the resource group, including its subscriptions, Content Safety resource, Application Insights resource, and Log Analytics workspace. It removes everything in that group, so use a dedicated lab resource group. Confirm cleanup succeeded in the notebook output and Azure portal.

Your external Web IQ account and API key, Web IQ client-ID binding, and any Azure OpenAI deployment outside the lab resource group remain. Remove the Web IQ binding for the deleted APIM managed identity when no longer needed. Local `.env` and `params.json` files also remain and can be removed when you no longer need them.

### References

- [Microsoft Web IQ overview](https://webiq.microsoft.ai/documentation/overview/)
- [Web IQ authentication](https://learn.microsoft.com/en-us/web-iq/get-started/authentication)
- [APIM managed-identity authentication examples](https://learn.microsoft.com/en-us/azure/api-management/authentication-managed-identity-policy#examples)
- [Web IQ Web Search response schema](https://webiq.microsoft.ai/documentation/api-reference/web/#web-response)
- [Web IQ MCP documentation](https://webiq.microsoft.ai/documentation/mcp/)
- [Web IQ citation and click instrumentation](https://webiq.microsoft.ai/documentation/instrumentation/)
- [Azure API Management custom metrics policy](https://learn.microsoft.com/azure/api-management/emit-metric-policy)
- [Content Safety Analyze Text API](https://learn.microsoft.com/rest/api/contentsafety/text-operations/analyze-text?view=rest-contentsafety-2024-09-01)
- [APIM send-request policy](https://learn.microsoft.com/azure/api-management/send-request-policy)
- [Azure OpenAI Responses API: remote MCP servers](https://learn.microsoft.com/azure/foundry/openai/how-to/responses#using-remote-mcp-servers)
