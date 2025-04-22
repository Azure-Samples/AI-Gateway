---
sidebar_position: 3
---

# Control and monitor your token consumption: Part I  

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

Importing Azure Open AI like this through the guide did somethings for us, so let's see what that was.

### -2- Configure the policy on the API

TODO, show the xml you are adding to inbound policy and what it does

### -4- Test out the policy

TODO, make a request, make sure you get rate limited and show the 400 error.

## Additional Resources

Here's a list of resources that you might find useful:

- [Policy docs page](https://learn.microsoft.com/en-us/azure/api-management/azure-openai-token-limit-policy)

- [Azure Sample](https://github.com/Azure-Samples/genai-gateway-apim)

- [Azure Gateway](https://github.com/Azure-Samples/AI-Gateway)
 
## Infrastructure as Code

To deploy this in production, you need to specify your cloud resources in Bicep files and use either Azure CLI or Azure Developer CLI, azd. Follow below lab to learn how.

TODO: add link to lab