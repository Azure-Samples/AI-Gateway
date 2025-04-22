---
sidebar_position: 2
---

# Dynamic Load Balancing


<!-- Structure 
step by step on how to set this up on the azure portal;
each step should include a screenshot and conceptual explanation;
should include a basic test on the portal;

conceptual explanation at a high level:
- typical prioritized PTU with fallback consumption scenario
- backend pool uses round-robin by default
- In Azure API Management, you can set up your different LLMs as backends and define structures to route requests to prioritized backends and add automatic circuit breaker rules to protect backends from too many requests.
- Under normal conditions, if your Azure OpenAI service fails, users of your application will continue to receive error messages, an experience that will persist until the backend issue is resolved and becomes ready to serve requests again.
- To set up load balancing across the backends, you can either use one of supported approaches/ strategies or a combination of two to ensure optimal use of your Azure OpenAI resources.

steps at a high level:
1. create a resource group
2. create an APIM instance (Basicv2). Save apim service id, gateway url, and subscription key
3. Deploy 3 openai (name: gpt-4o-mini, model version: 2024-07-18, capacity: 8, sku: standard, api version: 2024-02-01) instances (1 for each region - eastus, westus, swedencentral)
4. Then test with eastus, westus and swedencentral to show default round-robin load balancing
4. Then test with eastus (priority 1), westus (priority 2), swedencentral (priority 3) to show priority based load balancing
5. Then test with eastus (priority 1), westus (priority 2, weight 50), swedencentral (priority 2, weight 50) to show weighted load balancing
6. Where applicable, show how you can use azure copilot to understand policies further
7. this should link back to the jupyter notebooks to show how to use the same policies in bicep deployment and python


resources:
1. Backends in APIM - https://learn.microsoft.com/en-us/azure/api-management/backends?tabs=bicep
2. Improve LLM backend resiliency with load balancer and circuit breaker rules in Azure API Management Blog - https://techcommunity.microsoft.com/blog/azuredevcommunityblog/improve-llm-backend-resiliency-with-load-balancer-and-circuit-breaker-rules-in-a/4394502
-->

## Introduction: The Challenge of LLM Resiliency

When building AI applications that rely on Large Language Models (LLMs), ensuring reliable and cost-effective access to these models presents several challenges:

- **Service Availability:** _What happens when an Azure OpenAI service experiences downtime or throttling?_
- **Regional Reliability:** _How do you maintain operations if a specific Azure region faces issues?_
- **Cost Optimization:** _How can you balance between reserved capacity (Provisioned Throughput Units PTU) and consumption-based pricing?_
- **Performance:** _How can you ensure consistent response times for users regardless of backend load?_

Without proper management, these issues can lead to application failures, inconsistent user experiences, and unexpected costs. When your primary OpenAI service fails, your application users typically receive error messages until the backend issue resolves - a frustrating experience especially for mission-critical applications.

## Solution: Backend Pool Load Balancing in Azure API Management

Azure API Management (APIM) provides a powerful solution through its backend pool functionality that allows you to:

- **Distribute Load:** Route requests across multiple Azure OpenAI services
- **Implement Failover:** Automatically redirect traffic when primary services are unavailable
- **Optimize Resource Usage:** Prioritize dedicated capacity before falling back to consumption-based instances
- **Manage Traffic Intelligently:** Use priority and weight-based routing for fine-grained control

### Understanding the Prioritized PTU with Fallback Scenario

The pattern we'll implement is a **Prioritized PTU with Fallback Consumption** scenario with:

1. **Primary Tier (Priority 1):** A Provisioned Throughput Unit (PTU) Azure OpenAI service that offers dedicated capacity at a fixed cost
2. **Secondary Tier (Priority 2):** Multiple consumption-based Azure OpenAI services that you only pay for when used

This pattern will allow you to:

- Maximize utilization of your pre-paid PTU capacity
- Automatically scale to consumption-based instances when demand exceeds PTU capacity
- Maintain service availability even if one or more regions experience issues

![backend pool load balancing](/img/backend-pool-load-balancing.gif)

## Step-by-Step Implementation

### Step 1: Create resources

**Resource Group**

1. Go to the [Azure Portal](https://portal.azure.com/)
2. Click on **Resource groups** and **+ Create**
    - Select a _Subscription_
    - Enter a _Resource group name_ (e.g., `wrsh-openai-loadbalancing`)
    - Select a _Region_ (e.g., `West Europe`)
3. Click on **Review + Create** and then **Create**
    ![backend pool load balancing create resource group ](/img/wrsh-loadbalancing-create-rg.png)

**API Management Service**

4. In your newly created resource group, click on **+ Create** and in the search bar, type **API Management** and select **API Management service**
5. Click on **Create**
    - Select a _Subscription_
    - Select the _Resource group_ you just created
    - Select a _Region_ (e.g., `West Europe`)
    - Enter a _Resource name_ (e.g., `wrsh-openai-loadbalancing-apim`)
    - Enter _Organization name_ (e.g., `Microsoft`)
    - Enter _Administrator email_ (e.g., `noreply@microsoft.com`)
    - Select the **Basic v2** pricing tier
    - Select **1** for the number of units
    - Switch to the **Managed Identity** tab and check the **Status** to enable system-assigned managed identity
    - Click on **Review + Create** and then **Create**

**Azure OpenAI Services**

6. In your resource group, click on **+ Create** and in the search bar, type **Azure OpenAI** and select **Azure OpenAI**
7. Click on **Create**
    - Select a _Subscription_
    - Select the _Resource group_ you just created
    - Select **East US** for the _Region_
    - Enter **wrsh-openai-eastus** for the a _Resource name_
    - Select the **Standard** pricing tier
    - Click on **Next** and leave the default settings
    - In the **Review + Create** tab, click on **Create**
    ![backend pool load balancing create azure openai resource in EastUS](/img/wrsh-loadbalancing-openai-eastus.png)
    
8. Repeat the above steps to create two more Azure OpenAI services:
    - **West US**: `wrsh-openai-westus`
    - **Sweden Central**: `wrsh-openai-swedencentral`
9. You need to assign the **Managed Identity** of your API Management service to the **Cognitive Services User** role in each of your Azure OpenAI services. To do this:
    - Navigate to your Azure OpenAI resource and click on **Access control (IAM)**
    - Click on **+ Add role assignment**
        - Select **Cognitive Services User** as the _Role_
        - Select **Managed identity** as the _Assign access to_
        - Select your API Management service (e.g., `wrsh-openai-loadbalancing-apim`) as the _Managed identity_
    - Click on **Save** to assign the role
    - Repeat this step for all three Azure OpenAI services
10. You need to deploy models in each of the Azure OpenAI services. For each of your Azure OpenAI services:
    - Right click on **Go to Azure AI Foundry portal** and open AI Foundry in a new tab. Ensure your Azure OpenAI resource is selected
    ![backend pool load balancing AI Foundry select resource](/img/wrsh-loadbalancing-ai-foundry-eastus.png)
    - Click on **Deployments** and then **+ Deploy model** >> **Deploy base model**
    ![backend pool load balancing create azure openai resource in EastUS](/img/wrsh-loadbalancing-to-ai-foundry.png)
    - Enter **gpt-4o-mini** and click on **Confirm**
    ![backend pool load balancing select model](/img/wrsh-loadbalancing-gpt-4o-mini-selection.png)
    - On the model deployment card, expand **Customize** and:
        - Retain _Deployment name_ as **gpt-4o-mini**
        - Select **Standard** as the _deployment type_ 
        - Retain **2024-07-18** as the default _model version_
        - Set _Tokens per minite (TPM) rate limit/Capacity_ to **8** and click on **Deploy**
    ![backend pool load balancing gpt-4o-mini deployment](/img/wrsh-loadbalancing-gpt-4o-config.png)
    - Repeat the above steps for the other two Azure OpenAI services, ensuring you set the same model version and capacity

### Step 2: Configure API Management (Backend Pool)

1. First you'll need to get the **Endpoint URLs** for each of your Azure OpenAI services. 
    - Navigate to your Azure OpenAI resource and click on **Endpoints**, then copy the **Endpoint** and save it for a later step.
    - Do this for all three Azure OpenAI services.

2. Navigate to your API Management service and expand the **APIs** section
3. You will now add the Azure OpenAI services as backends to your API Management service. Click on **Backends** and then **+ Create new backend**
![backend pool load balancing create backend](/img/wrsh-loadbalancing-create-backend.png)
    - Enter a _Name_ (e.g., `openai-eastus`)
    - Select **Custom URL** as the _Backend hosting type_
    - Paste in the **Endpoint URL** you copied earlier

    **Backend pool**

     Skip this for now, as we will create a load balanced pool in the next step

    **Circuit breaker rule**

    - Click on **+ Create new** for the _Add a circuit breaker rule_ option
        - Enter a _Name_ (e.g., `openAIBreakerRule`)
        - Leave _Failure count_ as **1**
        - Set _Failure interval_ to **5 minutes**
        ![backend pool load balancing circuit breaker rule name](/img/wrsh-loadbalancing-circuit-rule-name.png)
        - Specify _Custom range_ as **429**
        - Set _Trip duration_ to **1 minute**
        - Check **True (Accept)** for the _Check 'Retry-After' header in HTTP reponse_
        ![backend pool load balancing circuit breaker range](/img/wrsh-loadbalancing-circuit-range.png)

- Click on **Create** to add the Azure OpenAI service as a backend
- Repeat the above steps for the other two Azure OpenAI services, ensuring you set the same circuit breaker rule for each backend
    - **Backend 2**
        - Name: `openai-westus`
        - Circuit breaker rule: `openAIBreakerRule`

    - **Backend 3**
        - Name: `openai-swedencentral`
        - Circuit breaker rule: `openAIBreakerRule`

    ![backend pool load balancing all backends](/img/wrsh-loadbalancing-all-backends.png)

4. Next, you will need to create a **Load Balanced Pool** for your Azure OpenAI services. Click on **Load balancer** and then **+ Create new pool**
![backend pool load balancing create load balanced pool](/img/wrsh-loadbalancing-create-pool.png)
    - Enter a _Name_ (e.g., `openai-backend-pool`)
    - Check all three backends you created earlier for the _Add backends to pool_ option
    - Leave the _Backend weight and priority_ as **Send requests evenly** to distribute requests evenly across all backends (Round Robin)

### Step 3: Create an API for OpenAI
1. In your API Management service, click on **APIs**, scroll to **Create from Azure resource** and then select **Azure OpenAI Service**
![backend pool load balancing import from AOI](/img/wrsh-loadbalancing-import-from-aoi.png)
    - Select an _Azure OpenAI instance_ (e.g., `wrsh-openai-eastus`)
    - Select **2024-02-01** as the _Azure OpenAI API version_
    - Enter a _Display name_ (e.g., `OpenAI`)
    - Check the **Improve SDK compatibility** option, which will postfix the base url with `/openai`
    ![backend pool load balancing import from AOI config](/img/wrsh-loadbalancing-import-config.png)
    - Click on **Review + Create** and then **Create**

2. You now need to configure API Policies for the API you just created. Click on **APIs** and select the API you just created (e.g., `OpenAI`)
    - Select **Design**, then **Inbound processing** and click on the "Policy Code Editor" icon to open the policy editor. Replace the existing policy with the following code:

        ```xml 
        <policies>
            <inbound>
                <base />
                <authentication-managed-identity resource="https://cognitiveservices.azure.com" output-token-variable-name="managed-id-access-token" ignore-error="false" />
                <set-header name="Authorization" exists-action="override">
                    <value>@("Bearer " + (string)context.Variables["managed-id-access-token"])</value>
                </set-header>
                <set-backend-service backend-id="openai-backend-pool" />
            </inbound>
            <backend>
                <!--Set count to one less than the number of backends in the pool to try all backends until the backend pool is temporarily unavailable.-->
                <retry count="2" interval="0" first-fast-retry="true" condition="@(context.Response.StatusCode == 429 || (context.Response.StatusCode == 503 && !context.Response.StatusReason.Contains("Backend pool") && !context.Response.StatusReason.Contains("is temporarily unavailable")))">
                    <forward-request buffer-request-body="true" />
                </retry>
            </backend>
            <outbound>
                <base />
            </outbound>
            <on-error>
                <base />
                <choose>
                    <!--Return a generic error that does not reveal backend pool details.-->
                    <when condition="@(context.Response.StatusCode == 503)">
                        <return-response>
                            <set-status code="503" reason="Service Unavailable" />
                        </return-response>
                    </when>
                </choose>
            </on-error>
        </policies>
        ```
        This policy does the following:
        - Uses a managed identity to authenticate with the Azure OpenAI service
        - Sets the backend service to the load balanced pool you created earlier
        - Implements a retry policy that retries requests to the backend if it receives a 429 (Too Many Requests) status code or a 503 (Service Unavailable) status code

    - Click on **Save** to save the policy
    

### Step 4: Test your Load Balancing Setup

### Round-Robin

Round-robin load balancing is the default behavior of Azure API Management. API Management will distribute requests evenly across all backends in the pool. To test this, 

    1. In your APIM instance, go to "APIs" and select your "OpenAI" API
    2. Select the `POST Creates a completion for the chat` operation 
    3. Click on **Test** and for

        **Template parameters**:
        - **deployment-id**: `gpt-4o-mini`
        - **api-version**: `2024-02-01`
        ![backend pool load balancing test template parameters](/img/wrsh-loadbalancing-api-template-parameters.png)

        **Request body**:
        ```json
        {
            "messages": [
                {"role": "system", "content": "You are a sarcastic, unhelpful assistant."},
                {"role": "user", "content": "What is the weather like today?"}
            ]
        }
        ```

    4. Click on **Send** to send the request. Run the test multiple times and observe the "x-ms-region" header in the response. You'll notice that the requests are being distributed evenly across all three backends in the pool (East US, West US, and Sweden Central).
    ![backend pool load balancing round robin test](/img/wrsh-loadbalancing-round-robin.gif)

        ![backend pool load balancing round robin result](/img/wrsh-loadbalancing-round-robin-results.png)

### Priority-Based Load Balancing

Priority-based routing ensures backends with lower priority values (high priority) get traffic first. Only when higher-priority backends are unavailable or overloaded will traffic flow to lower-priority backends.

> **Note:** 
> - Higher weight values receive proportionally more traffic
> - Used to distribute load between equally important backends
> - Can be adjusted to account for different backend capacities

For example, if you were to set the following priorities:
- **East US**: Priority 1
- **West US**: Priority 2
- **Sweden Central**: Priority 3

The expected behavior would be that requests would be sent to the East US backend first. If it is unavailable, requests would then be sent to the West US backend, and finally to the Sweden Central backend.

    ![backend pool load balancing priority based load balancing results](/img/wrsh-loadbalancing-priority-based-results.png)

### Weighted Load Balancing

Weighted load balancing allows you to assign different weights to each backend in the pool. This means that some backends will receive more traffic than others based on their assigned weight. Within the same priority level, weights determine the proportion of traffic each backend receives: 

To test this, you will need to update the backend pool configuration to set priorities for each backend:
    1. In your APIM instance, go to **Backends**, switch to **Load balancer** and select the **openai-backend-pool** you created earlier
    2. Click on **Backends** and select the **Customize weight and priority** option, then set the following:
        - **East US**: Priority 1
        - **West US**: Priority 2, Weight 50
        - **Sweden Central**: Priority 2, Weight 50
    ![backend pool load balancing weighted load balancing](/img/wrsh-loadbalancing-customize-weights.png)
    3. Click on **Save** to save the changes
    4. Now return to the **APIs** section to test the API again. You can use the same test as before, but this time you should see that the requests are being distributed based on the weights you set. The East US backend should receive more traffic than the West US and Sweden Central backends.

        ![backend pool load balancing weighted load balancing test](/img/wrsh-loadbalancing-weighted.gif)

        ![backend pool load balancing weighted load balancing results](/img/wrsh-loadbalancing-weighed-results.png)

## Conclusion
You learnt how to set up automated load balancing and failover for your Azure OpenAI services using Azure API Management. This setup allows you to ensure high availability, optimize resource usage, and provide a seamless experience for your users even in the face of backend failures.

## Additional Resources

<iframe width="560" height="315" src="https://www.youtube.com/embed/Y8bBtwb2MTs?si=Gz8tNscg73AhD2K9" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

Blog post: [Improve LLM backend resiliency with load balancer and circuit breaker rules in Azure API Management](https://techcommunity.microsoft.com/blog/azuredevcommunityblog/improve-llm-backend-resiliency-with-load-balancer-and-circuit-breaker-rules-in-a/4394502)