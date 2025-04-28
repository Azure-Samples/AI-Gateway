---
sidebar_position: 1
---
 
# Create Azure resources

Here we will create the needed Azure resources that we will use throughout this section.

## Exercise: Create Azure Open AI
 
Let's create an Azure Open AI cloud resource.

### -1- Create an Azure Open AI instance

- Navigate to [Azure Portal](https://portal.azure.com).

- Search for **Azure Open AI** and select "Create" button.

  ![Create Azure Open AI](/img/token-limit-1.png)
 
- Fill out all the values and create the resource.

  ![Fill out Azure Open AI information](/img/token-limit-2.png)
 
### -2- Create a deployment on your Azure Open AI instance

- Navigate to your deployed Azure Open AI instance and select "Go to Azure AI Foundry Portal". 

  ![Go to Azure AI Foundry](/img/token-limit-3.png)

  You should now see a user interfance like so:

  ![Azure AI Foundry](/img/token-limit-4.png)

- Select "Deployments" in the left menu and select "+ Deploy model" and select "base model"
- Type **gpt-4o**, select the model from the list and click "Confirm".

  Now you are all set. 

## Exercise: Create an Azure API Management instance

- In Azure Portal, type **Azure API Management services**. 
- Select "+ Create" and fill in the needed information to create a new Azure API Management instance.

  ![Create Azure API Management resource](/img/token-limit-5.png)


  Great, now that we Azure Open AI deployments and Azure API Management created, we can move on to the next activity which is to load balance between Azure Open AI instances.

## Exercise: Create Application Insights instance 

1. Sign in to the Azure portal and create an Application Insights resource.
1. ![Select Application Insights](https://learn.microsoft.com/en-us/previous-versions/azure/azure-monitor/app/media/create-new-resource/new-app-insights.png)
1. Fill in the following values:

   | Settings | Value | Description |
   |--|--|--|
   | Name | Unique value | Fill in a unique value |
   | Resource group | New or existing resource group | Fill in new or existing resource group |
   | Region | Fill in region | Fill in a region close to you |
   | Resource mode | Classic or workspace-based | Workspace-based resources allow you to send your Application Insights telemetry to a common Log Analytics workspace |

1. Here's how you can fill it out:

  ![Example of fille in resource blade](https://learn.microsoft.com/en-us/previous-versions/azure/azure-monitor/app/media/create-new-resource/review-create.png)

Learn more how to [provision an Application Insights resource here](https://learn.microsoft.com/previous-versions/azure/azure-monitor/app/create-new-resource?tabs=net). 

## Additional Resources

- Docs: [Create Azure API Management instance](https://learn.microsoft.com/en-us/azure/api-management/get-started-create-service-instance)
- Docs: [Create Azure Open AI](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/create-resource?pivots=web-portal)
- Docs: [Create Azure Application Insight instance](https://learn.microsoft.com/en-us/azure/azure-monitor/app/create-workspace-resource?tabs=portal)

## Infrastructure as Code

- Lab: [Folder with Bicep recipes for different resources](https://github.com/Azure-Samples/AI-Gateway/tree/main/modules)