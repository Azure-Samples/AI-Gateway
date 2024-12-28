# type: ignore

stdout = ! az deployment group show --name {deployment_name} -g {resource_group_name} --query properties.outputs.apimServiceId.value -o tsv
apim_service_id = stdout.n
print(f"👉🏻 APIM Service Id: {apim_service_id}")

stdout = ! az deployment group show --name {deployment_name} -g {resource_group_name} --query properties.outputs.apimSubscriptionKey.value -o tsv
apim_subscription_key = stdout.n
print(f"👉🏻 APIM Subscription Key (masked): ****{apim_subscription_key[-4:]}")

stdout = ! az deployment group show --name {deployment_name} -g {resource_group_name} --query properties.outputs.apimResourceGatewayURL.value -o tsv
apim_resource_gateway_url = stdout.n
print(f"👉🏻 APIM API Gateway URL: {apim_resource_gateway_url}")

stdout = ! az deployment group show --name {deployment_name} -g {resource_group_name} --query properties.outputs.logAnalyticsWorkspaceId.value -o tsv
workspace_id = stdout.n
print(f"👉🏻 Workspace ID: {workspace_id}")

stdout = ! az deployment group show --name {deployment_name} -g {resource_group_name} --query properties.outputs.applicationInsightsAppId.value -o tsv
app_id = stdout.n
print(f"👉🏻 App ID: {app_id}")

stdout = ! az deployment group show --name {deployment_name} -g {resource_group_name} --query properties.outputs.functionAppResourceName.value -o tsv
function_app_resource_name = stdout.n
print(f"👉🏻 Function Name: {function_app_resource_name}")

stdout = ! az deployment group show --name {deployment_name} -g {resource_group_name} --query properties.outputs.cosmosDBConnectionString.value -o tsv
cosmosdb_connection_string = stdout.n
print(f"👉🏻 Cosmos DB Connection String: {cosmosdb_connection_string}")
