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
 
## Exercise: Create Azure Open AI instance
 
### -1- Create an Azure Open AI instance

- Navigate to [Azure Portal](https://portal.azure.com).

- Search for **Azure Open AI** and select "Create" button.

  ![Create Azure Open AI](/img/token-limit-1.png)
 
- Fill out all the values and create the resource.

  ![Fill out Azure Open AI information](/img/token-limit-2.png)

h2: Exercise: Track token consumption
 
A step by step guide how to set this up in Azure Portal including cloud resource creation and needed configuration
 
### -2- Create a deployment on your Azure Open AI instance

- Navigate to your deployed Azure Open AI instance and select "Go to Azure AI Foundry Portal". 

  ![Go to Azure AI Foundry](/img/token-limit-3.png)

  You should now see a user interfance like so:

  ![Azure AI Foundry](/img/token-limit-4.png)

- Select "Deployments" in the left menu and select "+ Deploy model" and select "base model"
- Type **gpt-4o**, select the model from the list and click "Confirm".

  Now you are all set. 

## Exercise: Create and configure an Azure API Management instance

In this exercise, we will create an Azure API Management instance and configure it to limit tokens.

### -1- Create an Azure API Management instance

- In Azure Portal, type **Azure API Management services**. 
- Select "+ Create" and fill in the needed information to create a new Azure API Management instance.

  ![Create Azure API Management resource](/img/token-limit-5.png)

### -2- Import the Azure Open AI instance as API

We've already created the Azure Open AI instance, next step is to import to our Azure Open AI istance

### -1- Map the Azure Open AI instance to Azure API management backend instances.

### -2- Configure the policy on the API

### -3- Test out the policy


## Resources

Here's a list of resources that you might find useful:

- [Policy docs page](https://learn.microsoft.com/en-us/azure/api-management/azure-openai-token-limit-policy)

- [Azure Sample](https://github.com/Azure-Samples/genai-gateway-apim)

- [Azure Gateway](https://github.com/Azure-Samples/AI-Gateway)

## Infrastructure as Code

To deploy this in production, you need to specify your cloud resources in Bicep files and use either Azure CLI or Azure Developer CLI, azd. Follow below lab to learn how.

TODO: add link to lab