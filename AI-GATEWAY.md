<!-- markdownlint-disable MD033 -->

# You need to install [VS Code Reveal extension](https://marketplace.visualstudio.com/items?itemName=evilz.vscode-reveal) and then click on 'slides' at the botton to view in presentation mode

title: AI Gateway
theme: black
enableMenu: true
parallaxBackgroundImage: ../images/back.png
parallaxBackgroundSize: 1500px 1024px

---

AI Gateway {style="font-size:60px"}

<img src="../images/ai-gateway.gif" alt="drawing" style="width:900px;"/>

---

AI Gateway objectives

* Aims to accelerate the experimentation of advanced AI use cases {style="font-size:20px"}
* Ensures control and governance over the consumption of AI services {style="font-size:20px"}
* Paves the road for a confident deployment of Intelligent Apps into production {style="font-size:20px"}

---

AI Gateway toolchain

<img src="../images/toolchain.png" alt="drawing" style="width:900px;"/>

---

* Powered by VS Code running locally or in the cloud with GitHub Codespaces {style="font-size:20px"}
* Jupyter Notebooks structures the step-by-step instructions {style="font-size:20px"}
* Python scripts define the variables and  execute OpenAI API calls directly or with SDKs {style="font-size:20px"}
* Bicep defines the infrastructure as code needed for the lab in a declarative way {style="font-size:20px"}
* Azure CLI handles authentication with Azure and  issues commands to the control plane {style="font-size:20px"}

---

Request forwarding

Playground to try forwarding requests to either an Azure OpenAI endpoint or a mock server {style="font-size:20px"}

<img src="../images/request-forwarding.gif" alt="drawing" style="width:700px;"/>

---

* Azure API Management uses the managed identity (user or system assigned).  {style="font-size:20px"}
* Azure API Management is authorized to consume the Azure OpenAI API through Role Based Access Controls.  {style="font-size:20px"}
* Zero impact on consumers using the API directly, with SDKs or orchestrators like LangChain. Just need to update the endpoint to use the Azure API Management endpoint instead of Azure OpenAI endpoint.  {style="font-size:20px"}
* Keyless approach: API consumers use the Azure API Management subscription keys, and the Azure OpenAI keys are never used  {style="font-size:20px"}

---

Backend circuit breaking

Playground to try the built-in backend circuit breaker functionality of Azure API Management to either an Azure OpenAI endpoint or a mock server {style="font-size:20px"}

<img src="../images/backend-circuit-breaking.gif" alt="drawing" style="width:700px;"/>

---

* Azure OpenAI endpoint is configured as an Azure API Management backend, promoting reusability across APIs and improved governance.   {style="font-size:20px"}
* Circuit breaking rules define controlled availability for the OpenAI endpoint.   {style="font-size:20px"}
* When the circuit breaks, Azure API Management stops sending requests to OpenAI.   {style="font-size:20px"}
* Handles the status code 429  (Too Many Requests) and any other status code sent by the OpenAI service.   {style="font-size:20px"}
* Doesn’t need any policy configuration. The rules are just properties of the backend.   {style="font-size:20px"}

---

Backend pool load balancing

Playground to try the built-in load balancing backend pool functionality of Azure API Management {style="font-size:20px"}

<img src="../images/backend-pool-load-balancing.gif" alt="drawing" style="width:700px;"/>

---

* Spread the load to multiple backends, which may have individual backend circuit breakers.  {style="font-size:20px"}
* Shift the load from one set of backends to another for upgrade (blue-green deployment).  {style="font-size:20px"}
* Currently, the backend pool supports round-robin load balancing.  {style="font-size:20px"}
* Doesn’t need any policy configuration. The rules are just properties of the backend.  {style="font-size:20px"}

---

Advanced load balancing

Playground to try the advanced load balancing (based on a custom Azure API Management policy) {style="font-size:20px"}

<img src="../images/advanced-load-balancing.gif" alt="drawing" style="width:600px;"/>

---

* Loads the load balancer configuration from a named value property.  {style="font-size:20px"}
* Uses backends to enable the combination with the built-in circuit breaking feature or chaining with the backend pool.  {style="font-size:20px"}
* The policy doesn't have to be changed to add/modify endpoints or configure the load balancer.  {style="font-size:20px"}
* Dynamically supports any number of OpenAI endpoints.  {style="font-size:20px"}
* Support advanced properties like priority or weights to give priority to Provisioned Throughput Unit (PTU).  {style="font-size:20px"}

---

Model Routing

Playground to try routing to a backend based on Azure OpenAI model and version  {style="font-size:20px"}

<img src="../images/model-routing.gif" alt="drawing" style="width:700px;"/>

---

* Built atop the *Built-in logging* lab.  {style="font-size:20px"}
* Enables using the same API Management endpoint to target different models in different backend pools comprised of different backends.  {style="font-size:20px"}
* Requires minor policy configuration based on how this pattern is applied by you.  {style="font-size:20px"}

---

Response streaming

Playground to try response streaming with Azure API Management and Azure OpenAI endpoints to explore the advantages and shortcomings associated with streaming {style="font-size:20px"}

<img src="../images/response-streaming.gif" alt="drawing" style="width:700px;"/>

---

* The client application receives the completions in chunks as it's being generated.  {style="font-size:20px"}
* Might improve the user experience for intelligent apps with a ChatGPT interface.  {style="font-size:20px"}
* Streaming responses doesn't include the usage field to tell how many tokens were consumed.  {style="font-size:20px"}
* Streaming in a production application makes it more difficult to moderate the content of the completions, as partial completions may be more difficult to evaluate.  {style="font-size:20px"}

---

Vector searching

Playground to try the Retrieval Augmented Generation (RAG) pattern with Azure AI Search, Azure OpenAI embeddings and Azure OpenAI completions {style="font-size:20px"}

<img src="../images/vector-searching.gif" alt="drawing" style="width:700px;"/>

---

* Implements the popular RAG pattern.  {style="font-size:20px"}
* Uses Azure AI Search as a vector store.  {style="font-size:20px"}
* Uses OpenAI to generate the embeddings.  {style="font-size:20px"}
* Supports key word search, hybrid search and semantic ranking.  {style="font-size:20px"}
* OpenAI completion is generated based on the user prompt and the AI search results.  {style="font-size:20px"}
* All the APIs from OpenAI and AI Search are served trough Azure API Management without using keys.  {style="font-size:20px"}

---

Built-in logging

Playground to try the built-in logging capabilities of API Management  {style="font-size:20px"}

<img src="../images/built-in-logging.gif" alt="drawing" style="width:700px;"/>

---

* The requests are logged into Application Insights and metrics available in Azure Monitor.  {style="font-size:20px"}
* Doesn’t need any policy configuration.  {style="font-size:20px"}
* Enables tracking request/response details and token usage with the provided notebook.  {style="font-size:20px"}
* Metrics from the Azure OpenAI service might be correlated to provide a holistic view on service usage.  {style="font-size:20px"}
* The notebook can be easily customized to accommodate specific use cases.  {style="font-size:20px"}
* Enables the creation of Azure dashboards for a single pane of glass monitoring approach.  {style="font-size:20px"}

---

SLM self-hosting

Playground to try the self-hosted phy-2 Small Language Model (SLM) trough the Azure API Management self-hosted gateway with OpenAI API compatibility  {style="font-size:20px"}

<img src="../images/slm-self-hosting.gif" alt="drawing" style="width:700px;"/>

---

* The Azure API Management self-hosted gateway is a containerized version of the default managed gateway.  {style="font-size:20px"}
* Useful for scenarios where we need to self-host an open-source model from platforms such as Hugging Face.  {style="font-size:20px"}
* In this playground we have used Phi-2 that is a SLM suited to try on a laptop.  {style="font-size:20px"}
* Both Azure API Management self-hosted gateway and the phy-2 could run on docker containers or in a Kubernetes cluster.  {style="font-size:20px"}

---

Summary

* The AI Gateway concept provides a range of labs that enables the experimentation of AI Services supported by an API management strategy.  {style="font-size:20px"}
* The experimentation will feed the design architecture and the landing zone that will go into production.  {style="font-size:20px"}
* The labs are based on Jupyter Notebooks to enable clear and documented instructions, Python scripts, Bicep IaC and Azure API Management policies.  {style="font-size:20px"}
* There is a backlog of experiments that we plan to implement to take this work further and enable more advanced use cases. Stay tuned 🙂  {style="font-size:20px"}

---

<!-- .slide: data-auto-animate data-auto-animate-easing="cubic-bezier(0.770, 0.000, 0.175, 1.000)" -->

## Want to know more?

[aka.ms/ai-gateway](https://aka.ms/ai-gateway)

<p><br/></p>
<div class="r-hstack justify-center">
<div data-id="box1" style="background: #F35325; width: 50px; height: 50px; margin: 10px; border-radius: 5px;"></div>
<div data-id="box2" style="background: #81BC06; width: 50px; height: 50px; margin: 10px; border-radius: 5px;"></div>
<div data-id="box3" style="background: #05A6F0; width: 50px; height: 50px; margin: 10px; border-radius: 5px;"></div>
<div data-id="box4" style="background: #FFBA08; width: 50px; height: 50px; margin: 10px; border-radius: 5px;"></div>
</div>

---

<!-- .slide: data-auto-animate data-auto-animate-easing="cubic-bezier(0.770, 0.000, 0.175, 1.000)" -->

<div class="r-hstack justify-center">
<div data-id="box1" data-auto-animate-delay="0" style="background: #F35325; width: 100px; height: 100px; margin: 10px;"></div>
<div data-id="box2" data-auto-animate-delay="0.1" style="background: #81BC06; width: 100px; height: 100px; margin: 10px;"></div>
</div>
<div class="r-hstack justify-center">
<div data-id="box3" data-auto-animate-delay="0" style="background: #05A6F0; width: 100px; height: 100px; margin: 10px;"></div>
<div data-id="box4" data-auto-animate-delay="0.1" style="background: #FFBA08; width: 100px; height: 100px; margin: 10px;"></div>
</div>

## Thank You {style="margin-top: 20px;"}
