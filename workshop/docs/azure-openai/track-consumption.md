---
sidebar_position: 3
---

# Keep visibility into AI consumption with model monitoring  

In this lesson we will use the Azure service, Azure API Management and show how by adding one of its policies to an LLM endpoint; you can monitor the usage of tokens.

## Scenario: Monitor your token consumption

Monitor your token consumption is important for many reasons:

- **Cost**, by seeing how much you spend, you will be able to take decisions to reduce it.
- **Fairness**. You want to ensure your apps gets a fair amount of token. This also leads to a better user experience as the end user will be able to get a response when they expect.

## Video

<iframe width="560" height="315" src="https://www.youtube.com/embed/2pW6Z2VwHmQ?si=NwKkyTUa17IPhHMm" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## How to approach it?

- Create an App Insights instance.
- Import an Azure Open AI instance as an API to your Azure API Management instance.
- Configure your Azure API Management API and its policy

## Exercise: Import Azure Open AI as API

:::important
Make sure you have completed the lesson on [setting up cloud resources](./create-resources.md) before continuing.
:::

1. In the Azure portal, navigate to your API Management instance.

1. In the left menu, under APIs, select APIs > + Add API.

1. Under **Create from Azure resource**, select Azure OpenAI Service.

   ![Import tile](https://learn.microsoft.com/en-us/azure/api-management/media/azure-openai-api-from-specification/azure-openai-api.png)

1. On the Basics tab:

    a. Select the Azure OpenAI resource that you want to import.

    b. Optionally select an Azure OpenAI API version. If you don't select one, the latest production-ready REST API version is used by default. Make a note of the version you selected. You'll need it to test the API.

    c. Enter a Display name and optional Description for the API, for example **aoai** and **My Azure Open AI** respectively.

1. In **Base URL**, append a path that your API Management instance uses to access the Azure OpenAI API endpoints. If you enable Ensure OpenAI SDK compatibility (recommended), /openai is automatically appended to the base URL.

    For example, if your API Management gateway endpoint is https://contoso.azure-api.net, set a Base URL similar to https://contoso.azure-api.net/my-openai-api/openai.

1. Optionally select one or more products to associate with the API. Select **Next**.

1. On the **Policies tab**, optionally enable policies to monitor and manage Azure OpenAI API token consumption. You can also set or edit policies later.

    ![Select track during import](/img/monitor-import-select-monitor.png)

    If selected, enter settings or accept defaults that define the following policies (see linked articles for prerequisites and configuration details):

    - Manage token consumption
    - Track token usage

1. Add dimensions you want to track, you can also do this at a later stage. Here's how you can add dimensions:

    ![Add dimensions](/img/monitor-import-setup-dimensions.png)

    
1. Select **Review + Create**.

1. After settings are validated, select **Create**.

Great, now the import is complete, let's test out our API.

### -1- Enable monitoring on the API

Now that we have imported our Azure Open AI instance, let's inspect what we got and test the API to make sure everything works.

1. Select your API **aoai** and select the **Settings** tab

    ![Select settings on the API](/img/monitor-enable.png)

1. Check *enable* checkbox and leave the rest as is.
1. Select **Save**

### -2- Inspect the API and policy on the API

1. Select **Design** tab.

    You should see a policy and all the dimensions you've select during import. You can add further dimensions if you wish. 

    ![Inspect policy](/img/monitor-inspect-policy.png)

1. Let's test the API by navigating to **Test** tab. 
1. Fill in the following values:

    | Settings | Value | Description |
    |--|--|--|
    | deployment-id | gpt-4o | your deployment ID, double check the name in Azure AI Foundry |
    | api version | 2024-02-01 | a supported schema
    | request body | ```{"messages":[{"role":"system", "content": "you are a friendly assistant"}, { "role": "user", "content": "how is the weather in London?" }]} ``` | a JSON request body that contains messages for the AI model. |

1. Select **Send**, you should see a request response coming back.

    ![Send request](/img/monitor-test-import.png)

## Exercise: Test monitoring

To test the monitoring, we need to run a few requests, then navigate to it and inspect it.

1. Run a few requests by going to your API, select the "Test" tab and fill in values for:

  | Field | Value |
  | -- | -- | 
  | Deployment Id | gpt-4o |
  | API Version | 2024-02-01 |
  | Request body | `{"messages":[{"role":"system", "content": "you are a friendly assistant"}, { "role": "user", "content": "how is the weather in London?" }]}` | 

1. In the menu, select Monitoring / Application Insights / Select your instance

   That should take you to your application insights resource.

1. Select Monitoring / Metrics

   That takes you to your dashboard. 
1. In Metrics namespace droplist, select **api management**, like so:

   ![api management entry in namespace](/img/monitor-metrics.png)

   Once you select that, Metrics droplist should filter down to some very interesting metrics like Completion Tokens, Prompt Tokens and Total Tokens.

1. Add all three metrics and you should see something similar to below image:

   ![metrics dashboard](/img/monitor-dashboard.png)

   Now you can see your prompts token (23), the number of tokens used to present a response (77.17) and the total number of tokens (100.17)

   If you want, try to test some more requests with different prompts and see how they show up on the dashboard. Below here's what it can look like with a new request, note how both the second smaller request (to the left in the screen) is present and the new request (to the right in the screen)

   ![metrics dashboard](/img/monitor-dashboard-2.png)

## Additional Resources

- Docs: [Emit token metric policy](https://learn.microsoft.com/en-us/azure/api-management/azure-openai-emit-token-metric-policy)
- Docs: [Set up Azure Monitor](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-use-azure-monitor)

## Infrastructure as Code

- Lab: [Token metrics emitting lab](https://github.com/Azure-Samples/AI-Gateway/blob/main/labs/token-metrics-emitting/README.MD)