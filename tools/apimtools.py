import os, sys, json, requests
sys.path.insert(1, '../shared')  # add the shared directory to the Python path
import utils
from azure.identity import DefaultAzureCredential
from azure.mgmt.apimanagement import ApiManagementClient
from azure.mgmt.apimanagement.models import SubscriptionKeysContract 

class APIMClientTool:
    def __init__(self, apim_resource_name, resource_group_name):
        self.apim_resource_name = apim_resource_name
        self.resource_group_name = resource_group_name

    def initialize(self):
        output = utils.run("az account show", "Retrieved az account", "Failed to get the current az account")

        if output.success and output.json_data:
            self.current_user = output.json_data['user']['name']
            self.tenant_id = output.json_data['tenantId']
            self.subscription_id = output.json_data['id']
            utils.print_info(f"Current user: {self.current_user}")
            utils.print_info(f"Tenant ID: {self.tenant_id}")
            utils.print_info(f"Subscription ID: {self.subscription_id}")

            client = ApiManagementClient(credential=DefaultAzureCredential(), subscription_id=self.subscription_id)

            api_management_service = client.api_management_service.get(self.resource_group_name, self.apim_resource_name)

            self.apim_service_id = api_management_service.id
            utils.print_info(f"APIM Service Id: {self.apim_service_id}")

            self.apim_resource_gateway_url = api_management_service.gateway_url
            utils.print_info("APIM Gateway URL: {self.apim_resource_gateway_url}")
            self.apim_subscriptions = []
            subscriptions = client.subscription.list(self.resource_group_name, self.apim_resource_name)
            for subscription in subscriptions:
                subscription_secrets = client.subscription.list_secrets(self.resource_group_name, self.apim_resource_name, str(subscription.name))
                self.apim_subscriptions.append({ "name": subscription.name, "key": subscription_secrets.primary_key})
                utils.print_info(f"Retrieved key {len(self.apim_subscriptions) - 1} for subscription: {subscription.name}")

    def discover_openai_api(self, api_name_filter):
        client = ApiManagementClient(credential=DefaultAzureCredential(), subscription_id=self.subscription_id)
        api_management_service = client.api_management_service.get(self.resource_group_name, self.apim_resource_name)
        apis = client.api.list_by_service(self.resource_group_name, self.apim_resource_name)
        for api in apis:
            if api_name_filter in api.name:
                self.openai_api_id = api.id
                self.openai_api_path = api.path
                utils.print_info(f"Found OpenAI API with id {self.openai_api_id} and path {self.openai_api_path}")
                break
        if not self.openai_api_id:
            utils.print_error(f"Failed to find OpenAI API with name filter {api_name_filter}")

    def get_debug_credentials(self, expire_after) -> str | None:
        request = {
            "credentialsExpireAfter": expire_after,
            "apiId": f"{self.apim_service_id}/apis/{self.openai_api_id}",
            "purposes": ["tracing"]
        }
        output = utils.run(f"az rest --method post --uri {self.apim_service_id}/gateways/managed/listDebugCredentials?api-version=2023-05-01-preview --body \"{str(request)}\"",
                "Retrieved APIM debug credentials", "Failed to get the APIM debug credentials")
        return output.json_data['token'] if output.success and output.json_data else None
         
    def get_trace(self, trace_id) -> str | None:
        request = {
            "traceId": trace_id
        }
        output = utils.run(f"az rest --method post --uri {self.apim_service_id}/gateways/managed/listTrace?api-version=2023-05-01-preview --body \"{str(request)}\"",
                "Retrieved trace details", "Failed to get the trace details")
        return output.json_data if output.success and output.json_data else None

