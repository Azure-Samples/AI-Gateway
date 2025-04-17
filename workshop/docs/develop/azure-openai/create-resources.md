---
sidebar_position: 1
---
 
# Create Azure resources

Here we will create the needed Azure resources that we will use throughout this section.

## Exercise: Create Azure Open AI instance
 
Let's create an Azure Open AI cloud resource.

## -1- Create an Azure Open AI instance

- Navigate to [Azure Portal](https://portal.azure.com).

- Search for **Azure Open AI** and select "Create" button.

  ![Create Azure Open AI](/img/token-limit-1.png)
 
- Fill out all the values and create the resource.

  ![Fill out Azure Open AI information](/img/token-limit-2.png)
 
## -2- Create a deployment on your Azure Open AI instance

- Navigate to your deployed Azure Open AI instance and select "Go to Azure AI Foundry Portal". 

  ![Go to Azure AI Foundry](/img/token-limit-3.png)

  You should now see a user interfance like so:

  ![Azure AI Foundry](/img/token-limit-4.png)

- Select "Deployments" in the left menu and select "+ Deploy model" and select "base model"
- Type **gpt-4o**, select the model from the list and click "Confirm".

  Now you are all set. 

## -3- Create an Azure API Management instance

- In Azure Portal, type **Azure API Management services**. 
- Select "+ Create" and fill in the needed information to create a new Azure API Management instance.

  ![Create Azure API Management resource](/img/token-limit-5.png)


  Great, now that we Azure Open AI deployments and Azure API Management created, we can move on to the next activity which is to load balance between Azure Open AI instances.

## Resources

TODO