---
sidebar_position: 2
---

# Control cost and performance with token quotas and limits  

Once you bring an LLM to production and exposes it as an API Endpoint, you need to consider how you "manage" such an API. There are many considerations to be made everything from caching, scaling, error management, rate limiting, monitoring and more. 

In this lesson we will use the Azure service, Azure API Management and show how by adding one of its policies to an LLM endpoint; you can control the usage of tokens.

## Scenario: Manage your token consumption

Manage your token consumption is important for many reasons:

- **Cost**, you want to stay on top of how much token you spend as this ultimately decides how much you are charged.
- **Fairness**. You want to ensure your apps gets a fair amount of token. This also leads to a better user experience as the end user will be able to get a response when they expect.

## Video

<iframe width="560" height="315" src="https://www.youtube.com/embed/tc-rUS_-FN0?si=TN6V6JYoLpQ9qnAM" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## How to approach it?

To control token spend, here's how we need to implement this at high level:

- Create an Azure Open AI instance.
  - Create a deployment for above instance.
- Create an Azure API Management instance.
  - Create an API on above Azure API Management instance (we can import it throught the UI).
  - Map the Aure Open instance to Azure API Management backend instances.
  - Configure the policy on the API manage the token consumption.

Now that we understand the plan, let's execute said plan.
 
## Exercise: Import the Azure Open AI instance as API

:::important
Make sure you have completed the lesson on [setting up cloud resources](./create-resources.md) before continuing.
:::

- Navigate to your newly created Azure API Management instance and select "API" in the menu like indicated in the image:

  ![Import Azure Open AI to Azure API Management](/img/token-limit-6.png) 

- Select your subscription and provide a name of your choosing.

  ![Fill in API details](/img/token-limit-7.png)

- On the next tab, fill in that you want to "Manage token consumption"

  ![Manage token consumption](/img/token-limit-8.png)

  Great, now it's time to configure the remaining parts, almost there!

### -1- Inspect the import

When we imported the Azure Open AI API, the following was done for us:

- Managed identity was setup as security. This means all the call you do are more secure and that identity management is handled by Azure. This is our best recommendation for security.
- A token limit policy was set up in for our API looking like so:

  ```xml
  <azure-openai-token-limit 
    tokens-per-minute="1000" 
    counter-key="@(context.Subscription.Id)" 
    estimate-prompt-tokens="true" 
  />
  ```

  Here we see how:
    - We can spend 1000 tokens per minute `tokens-per-minute="1000"`
    - How this is tracked by Subscription Id `counter-key="@(context.Subscription.Id)"`
    - How it estimates the number of tokens we're using for prompting.

- A backend is setup pointing to our Azure Open AI API, you can find it by navigating to  APIs / Backends. The runtime url field should have a value similar to `https://<name>-aoai.openai.azure.com/openai`. 

We've shown you the policy above but let's see how it works in the next section.

### -2- Configure and test the policy on the API

Now that we have everything setup, let's try see how we can configure the policy so we see how it works. Let's review our configuration:

  ```xml
  <azure-openai-token-limit 
    tokens-per-minute="1000" 
    counter-key="@(context.Subscription.Id)" 
    estimate-prompt-tokens="true" 
  />
  ```

  In the preceding XML, we need to spend more than 1000 tokens per minute to be rate limited. To make it easy to test, let's change this to 50 tokens and make several consecutive requests, this should make the policy react and stop as from making any further requests with in that minute, so witha policy like so:

    ```xml
  <azure-openai-token-limit 
    tokens-per-minute="50" 
    counter-key="@(context.Subscription.Id)" 
    estimate-prompt-tokens="true" 
  />
  ```

  and a JSON payload like so:

```json
{"messages":[{"role":"system", "content": "you are a friendly assistant"}, { "role": "user", "content": "how is the weather in London?" }]}
```

let's make a few requests, remember, we expect a 429 error to happen once we exhaust our allowed "tokens-per-minute value"

![rate limited](/img/rate-limited.png)

If you see the above image, that means the policy is working



## Additional Resources

Here's a list of resources that you might find useful:

- Docs: [Policy docs page](https://learn.microsoft.com/en-us/azure/api-management/azure-openai-token-limit-policy)

- Sample: [Azure Sample](https://github.com/Azure-Samples/genai-gateway-apim)

- Repo (with many demoes): [Azure Gateway](https://github.com/Azure-Samples/AI-Gateway)
 
## Infrastructure as Code

To deploy this in production, you need to specify your cloud resources in Bicep files and use either Azure CLI or Azure Developer CLI, azd. Follow below lab to learn how.

- Lab: [Token rate limit Lab](https://github.com/Azure-Samples/AI-Gateway/blob/main/labs/token-rate-limiting/README.MD)