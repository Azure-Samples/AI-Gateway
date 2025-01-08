# type: ignore
# codeql [python] suppress [py/unsafe-execution] "Using shell commands in Jupyter notebooks"

# Obtain all of the outputs from the deployment
stdout = ! az deployment group show --name {deployment_name} -g {resource_group_name} --query properties.outputs -o json
outputs = json.loads(stdout.n)

# Extract the individual properties
apim_service_id = outputs.get('apimServiceId', {}).get('value', '')
apim_subscription_key = outputs.get('apimSubscriptionKey', {}).get('value', '')
apim_subscription1_key = outputs.get('apimSubscription1Key', {}).get('value', '')
apim_subscription2_key = outputs.get('apimSubscription2Key', {}).get('value', '')
apim_subscription3_key = outputs.get('apimSubscription3Key', {}).get('value', '')
apim_resource_gateway_url = outputs.get('apimResourceGatewayURL', {}).get('value', '')
workspace_id = outputs.get('logAnalyticsWorkspaceId', {}).get('value', '')
app_id = outputs.get('applicationInsightsAppId', {}).get('value', '')
function_app_resource_name = outputs.get('functionAppResourceName', {}).get('value', '')
cosmosdb_connection_string = outputs.get('cosmosDBConnectionString', {}).get('value', '')

# Print the extracted properties if they are not empty
if apim_service_id:
    print(f"👉🏻 APIM Service Id: {apim_service_id}")

if apim_subscription_key:
    print(f"👉🏻 APIM Subscription Key (masked): ****{apim_subscription_key[-4:]}")

if apim_subscription1_key:
    print(f"👉🏻 APIM Subscription Key 1 (masked): ****{apim_subscription1_key[-4:]}")

if apim_subscription2_key:
    print(f"👉🏻 APIM Subscription Key 2 (masked): ****{apim_subscription2_key[-4:]}")

if apim_subscription3_key:
    print(f"👉🏻 APIM Subscription Key 3 (masked): ****{apim_subscription3_key[-4:]}")

if apim_resource_gateway_url:
    print(f"👉🏻 APIM API Gateway URL: {apim_resource_gateway_url}")

if workspace_id:
    print(f"👉🏻 Workspace ID: {workspace_id}")

if app_id:
    print(f"👉🏻 App ID: {app_id}")

if function_app_resource_name:
    print(f"👉🏻 Function Name: {function_app_resource_name}")

if cosmosdb_connection_string:
    print(f"👉🏻 Cosmos DB Connection String: {cosmosdb_connection_string}")
