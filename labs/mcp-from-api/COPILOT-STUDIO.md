# Configuring MCP Tools on Copilot Studio

This guide walks you through connecting MCP servers deployed on Azure API Management to [Microsoft Copilot Studio](https://copilotstudio.microsoft.com/). You will configure two scenarios:

- **Weather MCP** – No authorization required
- **Product Catalog MCP** – Protected by OAuth 2.0

> **Prerequisite:** Complete the [mcp-from-api lab](mcp-from-api.ipynb) first so that the MCP servers are deployed on your API Management instance.

---

## Part 1 – Weather MCP (No Authorization)

### Step 1 – Create a blank agent

1. Open [Copilot Studio](https://copilotstudio.microsoft.com/).
2. Create a new **blank agent**.

### Step 2 – Add the Weather MCP tool

1. Click the **Tools** tab, then click **Add a tool**.
2. Select **Model Context Protocol**.
3. Fill in the following fields:
   - **Server name:** Weather MCP
   - **Server description:** Weather MCP server tool
   - **Server URL:** `https://<APIM_NAME>.azure-api.net/weather-mcp/mcp`
4. For **Authentication**, select **None**.
5. Click **Create**.

### Step 3 – Create the connection

1. Click **Create new connection**.
2. Click **Create**.

### Step 4 – Add and configure

1. Click **Add and configure**.

### Step 5 – Test the Weather MCP

1. In the agent chat, enter:

   > What's the weather in Lisbon?

2. Verify that the `get-weather` tool was invoked successfully and a weather response is returned.

---

## Part 2 – Product Catalog MCP (OAuth 2.0)

This section requires registering two applications in Microsoft Entra ID and configuring OAuth 2.0 authentication end-to-end.

### Step 1 – Register the `catalog-mcp` app (Resource application)

#### Step 1.1 – Create the app registration

1. In the [Azure portal](https://portal.azure.com), navigate to **Microsoft Entra ID** > **App registrations**.
2. Click **New registration**.
3. Set the **Name** to `catalog-mcp`.
4. Click **Register**.

#### Step 1.2 – Expose an API

1. In the app registration, click **Expose an API**.
2. Click **Add** next to **Application ID URI** and accept the default value (e.g. `api://<CLIENT_ID>`).
3. **Copy the Application ID URI** to a notepad – you will need it later.

#### Step 1.3 – Add a scope

1. Click **Add a scope** and fill in:
   - **Scope name:** `user_impersonation`
   - **Who can consent?** Admins and users
   - **Admin consent display name:** User impersonation
   - **Admin consent description:** Allow client apps and agents to impersonate users
2. Click **Add scope**.

#### Step 1.4 – Create an app role

1. Navigate to **App roles** and click **Create app role**.
2. Fill in the following:
   - **Display name:** `product-catalog.read`
   - **Allowed member types:** Users/Groups
   - **Value:** `product-catalog.read`
   - **Description:** Reads product catalog information
3. Click **Apply**.

#### Step 1.5 – Add an owner

1. Navigate to **Owners** and click **Add owners**.
2. Select your user (the current user that is configuring the App registrations) and confirm.

#### Step 1.6 – Assign the App role to the user(s)/group(s)

1. Navigate to **Enterprise applications** and search for `catalog-mcp`.
2. Select **Users and groups** and add the user(s)/group(s) that you will use with Copilot. This step is needed to issue the roles claims as part of the jwt.

---

### Step 2 – Register the `copilot-studio-connections` app (Client application)

#### Step 2.1 – Create the app registration

1. Go back to **App registrations** and click **New registration**.
2. Set the **Name** to `copilot-studio-connections`.
3. Click **Register**.
4. **Copy the Application (client) ID** to a notepad.

#### Step 2.2 – Configure API permissions

1. Navigate to **API permissions**.
2. **Remove** the existing `User.Read` permission.
3. Click **Add a permission** > **Microsoft Graph** > **Delegated permissions** and select:
   - `email`
   - `openid`
   - `profile`
4. Click **Add permissions**.
5. Click **Add a permission** again, but this time select **My APIs** > **catalog-mcp**.
6. Under **Delegated permissions**, select `user_impersonation`.
7. Under **Application permissions**, select `product-catalog.read`.
8. Click **Add permissions**.

#### Step 2.3 – Grant admin consent

1. Click **Grant admin consent** and confirm.

#### Step 2.4 – Create a client secret

1. Navigate to **Certificates & secrets**.
2. Click **New client secret**.
3. Add an optional description and click **Add**.
4. **Copy the secret value** to a notepad immediately (it won't be shown again).

---

### Step 3 – Configure the Product Catalog Agent in Copilot Studio

#### Step 3.1 – Create the agent

1. Go back to [Copilot Studio](https://copilotstudio.microsoft.com/).
2. Create a new agent named **Product Catalog Agent**.

#### Step 3.2 – Add the Catalog MCP tool with OAuth

1. Navigate to the **Tools** tab and click **Add a Tool**.
2. Select **Model Context Protocol**.
3. Fill in the following fields:
   - **Server name:** Product Catalog MCP
   - **Server description:** Product Catalog MCP server tool
   - **Server URL:** `https://<APIM_NAME>.azure-api.net/catalog-mcp/mcp`
4. For **Authentication**, select **OAuth 2.0** and set Type to **Manual**.
5. Fill in the OAuth settings:
   - **Client ID:** *(the client ID from `copilot-studio-connections` app registration)*
   - **Client Secret:** *(the secret value you copied)*
   - **Authorization URL:** `https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/authorize`
   - **Token URL:** `https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token`
   - **Refresh URL:** `https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token`
   - **Scopes:** `openid profile email`
6. Click **Create**.

#### Step 3.3 – Configure the redirect URI

1. **Copy the Redirect URL** shown in Copilot Studio.
2. Go back to the **copilot-studio-connections** app registration in the Azure portal.
3. Navigate to **Authentication** > **Add a platform** > **Web**.
4. Paste the Redirect URI.
5. Check the **Access tokens** checkbox.
6. Click **Configure**.

#### Step 3.4 – Update the APIM policy audience

1. In the Azure portal, navigate to your **API Management** instance.
2. Open the **Product Catalog MCP** server API and navigate to **Policies**.
3. In the `<validate-jwt>` policy, replace the `<audiences>` section with the **Application ID URI** you copied earlier:

   ```xml
   <audiences>
       <audience>api://<CATALOG_MCP_CLIENT_ID></audience>
   </audiences>
   ```

#### Step 3.5 – Update the custom connector secret

1. Go to [Power Apps](https://make.powerapps.com/).
2. Navigate to **Discover** > **Custom connectors**.
3. Select the **product-catalog-mcp** connector and click to edit.
4. Click on **Security**, then click **Edit**.
5. Update the **Client Secret** with the value you copied to the notepad.
6. For the **Resource URL**, enter the **Application ID URI** (e.g. `api://<CATALOG_MCP_CLIENT_ID>`).
7. Click **Update connector**.

#### Step 3.6 – Complete the connection

1. Go back to Copilot Studio.
2. Click **Next**, then **Create new connection**, and click **Create**.
3. After connected, click **Add and configure**.

#### Step 3.7 – Test the Product Catalog MCP

1. Go back to Copilot Studio and open the **Product Catalog Agent**.
2. In the agent chat, enter:

   > Which electronic products do you have in the catalog?

3. Click **Allow** when prompted.
4. Verify the catalog tools are invoked and results are returned.

---

## Optional: Role‑Based Access Control (RBAC)

Role‑based access control (RBAC) using application roles and the roles claim

- Roles are defined in Entra ID
- Roles are assigned to users or groups

Roles are evaluated and enforced by Azure API Management with the following element as a child of validate-jwt tag.

```xml
    <required-claims>
        <claim name="roles" match="any">
            <value>product-catalog.read</value>
        </claim>
    </required-claims>
```

---

## Troubleshooting

### Debugging access token issues

If you get `401 Unauthorized` errors, you can inspect the access token being sent to APIM by adding the following snippet to the MCP server policy **before** the `<validate-jwt>` element:

```xml
<set-variable name="accessToken" value="@(context.Request.Headers.GetValueOrDefault("Authorization", "").Replace("Bearer ", ""))" />
<!-- Log the captured access token to the trace logs -->
<trace source="Access Token Debug" severity="information">
    <message>@("Access Token: " + (string)context.Variables["accessToken"])</message>
</trace>
```

This logs the access token to the **trace** table in Application Insights.

**To decode and inspect the token:**

1. Go to [https://jwt.ms](https://jwt.ms).
2. Paste the access token from the Application Insights trace log.
3. Verify that the `aud` (audience) claim matches the **Application ID URI** you configured (e.g. `api://<CATALOG_MCP_CLIENT_ID>`).

If the audience does not match, revisit [Step 3.4](#step-34--update-the-apim-policy-audience) and ensure the `<audience>` value in the `<validate-jwt>` policy matches the Application ID URI from the `catalog-mcp` app registration.

---

## Additional Resources

- [Understanding Authorization in MCP](https://modelcontextprotocol.io/docs/tutorials/security/authorization)
- [Copilot Studio MCP with OAuth – Copilot Camp](https://microsoft.github.io/copilot-camp/pages/make/copilot-studio/10-mcp-oauth/)
- [Deployment Guide: Copilot Studio Agent with MCP Server Exposed by API Management – Tech Community](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/deployment-guide-copilot-studio-agent-with-mcp-server-exposed-by-api-management-/4462432)
- [Validate JWT Policy – Azure API Management](https://learn.microsoft.com/en-us/azure/api-management/validate-jwt-policy)
- [Introducing Model Context Protocol (MCP) in Copilot Studio – Microsoft Copilot Blog](https://www.microsoft.com/en-us/microsoft-copilot/blog/copilot-studio/introducing-model-context-protocol-mcp-in-copilot-studio-simplified-integration-with-ai-apps-and-agents/)
- [MCP in Copilot Studio Lab – Power Platform MCP](https://microsoft.github.io/pp-mcp/labs/mcs-mcp/)
- [Camp 2: AI Gateway – Sherpa](https://azure-samples.github.io/sherpa/camps/camp2-gateway/)

