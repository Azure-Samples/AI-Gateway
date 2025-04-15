# Token Rate Limit 

Once you bring an LLM to production and exposes it as an API Endpoint, you need to consider how you "manage" such an API. There are many considerations to be made everything from caching, scaling, error management, rate limiting, monitoring and more. 

In this lesson we will use the Azure service, Azure API Management and show how by adding one of its policies to an LLM endpoint; you can control the usage of tokens.

## Resources

Here's a list of resources that you might find useful:

- [Policy docs page](https://learn.microsoft.com/en-us/azure/api-management/azure-openai-token-limit-policy)

- [Azure Sample](https://github.com/Azure-Samples/genai-gateway-apim)

- [Azure Gateway](https://github.com/Azure-Samples/AI-Gateway)

## Video

<iframe width="560" height="315" src="https://www.youtube.com/embed/tc-rUS_-FN0?si=TN6V6JYoLpQ9qnAM" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## What is a token limit policy?

A token limit policy is something you can apply to your API to limit the number of tokens that can be requested from it. The idea is that you configure the policy to allow a certain number of tokens to be requested within a certain time frame. If the limit is exceeded, the API will return an error message. Typically, you write a policy that specifies the number of tokens allowed and the time frame in which they can be requested.

![Token rate limiting](https://github.com/Azure-Samples/AI-Gateway/raw/main/images/token-rate-limiting-small.gif)

## Why do we need a token limit policy?
There are a few reasons why you might want to limit the number of tokens that can be requested from your API:

- **To prevent abuse of the API**, such as a single user making too many requests in a short period of time.

- **Availability**, to ensure that the API is available to all users, not just a few who are making too many requests. This is also known as rate limiting and the problem being addressed is called the "noisy neighbour" problem.

- **Security**, to prevent denial of service attacks, where an attacker tries to overwhelm the API with too many requests.

- **Cost**, to prevent excessive usage of the API, which could result in higher costs.

As you can see, there are many good reasons to limit the number of tokens.

## How it works

The idea is to specify below XML and thereby _author_ a policy that decides what should happen when a request comes in. 

```xml
<policies> 
  <inbound> 
    <base /> 
      <azure-openai-token-limit 
        counter-key="@(context.Subscription.Id)" 
        tokens-per-minute="400" 
        estimate-prompt-tokens="false" 
        retry-after-variable-name="token-limit-retry-after" 
      /> 
  </inbound> 
  <backend> 
    <base /> 
  </backend> 
  <outbound> 
    <base /> 
  </outbound> 
  <on-error> 
  <base /> 
  </on-error>
```

- **azure-openai-token-limit** policy is the element that limits the number of tokens that can be requested from the Open AI API. 

- **counter-key** attribute is used to specify the key that is used to track the number of tokens requested. In this case, we are using the `subscription ID` as the key. You can also use other keys, such as the User ID or the IP Address. Why you would use one key over another depends on your specific use case, for example, if you want to limit the number of tokens requested by a single user or by a single subscription.

- **tokens-per-minute** is the number of tokens that can be requested within a minute. In this case, we are allowing _400_ tokens per minute. Any attempt to use more than that would lead to an error message, specifically `429 Too Many Requests`

- **estimate-prompt-tokens** is a boolean value that specifies whether to estimate the number of tokens that will be requested in the future. If set to true, the policy will estimate the number of tokens that will be requested in the future and adjust the rate limit accordingly. If set to false, the policy will not estimate the number of tokens that will be requested in the future and will use the rate limit specified in the policy.

- **retry-after-variable-name** is the name of the variable that will be used to specify the number of seconds to wait before making another request. There's also the option to use the "retry-after" header to specify the number of seconds to wait before making another request. The reason to use a variable is that it allows you to customize the number of seconds to wait rather than using a fixed value.

## Lab