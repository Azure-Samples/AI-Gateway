---
sidebar_position: 4
---

# Control and monitor your token consumption: Part II  

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

## Exercise: Create App Insights instance 

TODO, https://learn.microsoft.com/en-us/previous-versions/azure/azure-monitor/app/create-new-resource?tabs=net

## Exercise: Import Azure Open AI as API

https://learn.microsoft.com/en-us/azure/api-management/azure-openai-api-from-specification

TODO, should describe import process, and to tick the monitoring box

## Exercise: configure Azure API Management for monitoring

See to what extent we need to do this or the import does it for us

https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-app-insights?tabs=rest

### Validate import

What did it to for us

### Configure policy

https://learn.microsoft.com/en-us/azure/api-management/azure-openai-emit-token-metric-policy#prerequisites

## Test monitoring

TODO, should show how to make requests and how it shows up in monitoring.

## Resources

TODO

## Infrastructure as Code

TODO, link to lab