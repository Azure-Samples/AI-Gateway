
# type: ignore

import time
from openai import AzureOpenAI

runs = 10
sleep_time_ms = 100

client = AzureOpenAI(
    azure_endpoint = apim_resource_gateway_url,
    api_key = apim_subscription_key,
    api_version = openai_api_version
)

for i in range(runs):
    print(f"▶️ Run {i+1}/{runs}:")

    messages = {"messages": [
        {"role": "system", "content": "You are a sarcastic, unhelpful assistant."},
        {"role": "user", "content": "Can you tell me the time, please?"}
    ]}

    start_time = time.time()
    response = client.chat.completions.create(model = openai_model_name, messages = messages)
    response_time = time.time() - start_time
    print(f"⌚ {response_time:.2f} seconds")
    print(f"💬 {response.choices[0].message.content}\n")

    time.sleep(sleep_time_ms/1000)
