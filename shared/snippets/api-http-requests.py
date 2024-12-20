import requests
import time

runs = 10
sleep_time_ms = 100
url = f"{apim_resource_gateway_url}/openai/deployments/{openai_deployment_name}/chat/completions?api-version={openai_api_version}"
api_runs = []

for i in range(runs):
    print(f"▶️ Run {i+1}/{runs}:")

    messages = {"messages": [
        {"role": "system", "content": "You are a sarcastic, unhelpful assistant."},
        {"role": "user", "content": "Can you tell me the time, please?"}
    ]}

    start_time = time.time()
    response = requests.post(url, headers = {'api-key':apim_subscription_key}, json = messages)
    response_time = time.time() - start_time
    print(f"⌚ {response_time:.2f} seconds")

    # Check the response status code and apply formatting
    if 200 <= response.status_code < 300:
        status_code_str = f"\x1b[1;32m{response.status_code} - {response.reason}\x1b[0m" # Bold and green
    elif response.status_code >= 400:
        status_code_str = f"\x1b[1;31m{response.status_code} - {response.reason}\x1b[0m" # Bold and red
    else:
        status_code_str = str(response.status_code)  # No formatting

    # Print the response status with the appropriate formatting
    print(f"Response status: {status_code_str}")
    print(f"Response headers: {response.headers}")

    if "x-ms-region" in response.headers:
        print(f"x-ms-region: \x1b[1;31m{response.headers.get("x-ms-region")}\x1b[0m") # this header is useful to determine the region of the backend that served the request
        api_runs.append((response_time, response.headers.get("x-ms-region")))

    if (response.status_code == 200):
        data = json.loads(response.text)
        print(f"Token usage: {data.get("usage")}\n")
        print(f"💬 {data.get("choices")[0].get("message").get("content")}\n")
    else:
        print(response.text)

    time.sleep(sleep_time_ms/1000)
