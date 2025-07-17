import datetime, json, os, subprocess, requests, time, traceback

# Define ANSI escape code constants vor clarity in the print commands below
RESET_FORMATTING = "\x1b[0m"
BOLD_BLUE = "\x1b[1;34m"
BOLD_RED = "\x1b[1;31m"
BOLD_GREEN = "\x1b[1;32m"
BOLD_YELLOW = "\x1b[1;33m"

print_command = lambda command='': print(f"⚙️ {BOLD_BLUE}Running: {command} {RESET_FORMATTING}")
print_error = lambda message, output='', duration='': print(f"❌ {BOLD_YELLOW}{message}{RESET_FORMATTING} ⌚ {datetime.datetime.now().time()} {duration}{' ' if output else ''}{output}")
print_info = lambda message: print(f"👉🏽 {BOLD_BLUE}{message}{RESET_FORMATTING}")
print_message = lambda message, output='', duration='': print(f"👉🏽 {BOLD_GREEN}{message}{RESET_FORMATTING} ⌚ {datetime.datetime.now().time()} {duration}{' ' if output else ''}{output}")
print_ok = lambda message, output='', duration='': print(f"✅ {BOLD_GREEN}{message}{RESET_FORMATTING} ⌚ {datetime.datetime.now().time()} {duration}{' ' if output else ''}{output}")
print_warning = lambda message, output='', duration='': print(f"⚠️ {BOLD_YELLOW}{message}{RESET_FORMATTING} ⌚ {datetime.datetime.now().time()} {duration}{' ' if output else ''}{output}")

class Output(object):
    def __init__(self, success, text):
        self.success = success
        self.text = text

        try:
            self.json_data = json.loads(text)
        except:
            self.json_data = json.loads("{}")   # return an empty JSON object if the output is not valid JSON rather than None as that makes consuming it easier this way

# Cleans up resources associated with a deployment in a resource group
def cleanup_resources(deployment_name, resource_group_name = None):
    if not deployment_name:
        print_error("Missing deployment name parameter.")
        return

    if not resource_group_name:
        resource_group_name = f"lab-{deployment_name}"

    try:
        print_info(f"🧹 Cleaning up resource group '{resource_group_name}'...")

        # Show the deployment details
        output = run(f"az deployment group show --name {deployment_name} -g {resource_group_name} -o json", "Deployment retrieved", "Failed to retrieve the deployment")

        if output.success and output.json_data:
            provisioning_state = output.json_data.get("properties").get("provisioningState")
            print_info(f"Deployment provisioning state: {provisioning_state}")

            # Delete AI Foundry projects
            output = run(f'az resource list -g {resource_group_name} --resource-type "microsoft.cognitiveservices/accounts/projects"', "Retrieved AI Foundry projects", "Failed to list AI Foundry projects")
            if output.success and output.json_data:
                for resource in output.json_data:
                    print_info(f"Deleting AI Foundry project '{resource['name']}' in resource group '{resource_group_name}'...")
                    output = run(f'az resource delete --ids "{resource['id']}"', f"AI Foundry project '{resource['name']}' deleted", f"Failed to delete AI Foundry project '{resource['name']}'")

            # Delete and purge CognitiveService accounts
            output = run(f"az cognitiveservices account list -g {resource_group_name}", f"Listed CognitiveService accounts", f"Failed to list CognitiveService accounts")
            if output.success and output.json_data:
                for resource in output.json_data:
                    print_info(f"Deleting and purging Cognitive Service Account '{resource['name']}' in resource group '{resource_group_name}'...")
                    output = run(f"az cognitiveservices account delete -g {resource_group_name} -n {resource['name']}", f"Cognitive Services '{resource['name']}' deleted", f"Failed to delete Cognitive Services '{resource['name']}'")
                    output = run(f"az cognitiveservices account purge -g {resource_group_name} -n {resource['name']} -l \"{resource['location']}\"", f"Cognitive Services '{resource['name']}' purged", f"Failed to purge Cognitive Services '{resource['name']}'")

            # Delete and purge APIM resources
            output = run(f" az apim list -g {resource_group_name}", f"Listed APIM resources", f"Failed to list APIM resources")
            if output.success and output.json_data:
                for resource in output.json_data:
                    print_info(f"Deleting and purging API Management '{resource['name']}' in resource group '{resource_group_name}'...")
                    output = run(f"az apim delete -n {resource['name']} -g {resource_group_name} -y", f"API Management '{resource['name']}' deleted", f"Failed to delete API Management '{resource['name']}'")
                    output = run(f"az apim deletedservice purge --service-name {resource['name']} --location \"{resource['location']}\"", f"API Management '{resource['name']}' purged", f"Failed to purge API Management '{resource['name']}'")

            # Delete and purge Key Vault resources
            output = run(f"az keyvault list -g {resource_group_name}", f"Listed Key Vault resources", f"Failed to list Key Vault resources")
            if output.success and output.json_data:
                for resource in output.json_data:
                    print_info(f"Deleting and purging Key Vault '{resource['name']}' in resource group '{resource_group_name}'...")
                    output = run(f"az keyvault delete -n {resource['name']} -g {resource_group_name}", f"Key Vault '{resource['name']}' deleted", f"Failed to delete Key Vault '{resource['name']}'")
                    output = run(f"az keyvault purge -n {resource['name']} --location \"{resource['location']}\"", f"Key Vault '{resource['name']}' purged", f"Failed to purge Key Vault '{resource['name']}'")

            # Delete the resource group last
            print_message(f"🧹 Deleting resource group '{resource_group_name}'...")
            output = run(f"az group delete --name {resource_group_name} -y", f"Resource group '{resource_group_name}' deleted", f"Failed to delete resource group '{resource_group_name}'")

            print_message("🧹 Cleanup completed.")

    except Exception as e:
        print(f"An error occurred during cleanup: {e}")
        traceback.print_exc()

def create_resource_group(resource_group_name, resource_group_location = None):
    if not resource_group_name:
        print_error('Please specify the resource group name.')
    else:
        output = run(f"az group show --name {resource_group_name}")

        if output.success:
            print_info(f"Using existing resource group '{resource_group_name}'")
        else:
            if not resource_group_location:
                print_error('Please specify the resource group location.')
            else:
                print_info(f"Resource group {resource_group_name} does not yet exist. Creating the resource group now...")

                output = run(f"az group create --name {resource_group_name} --location {resource_group_location} --tags source=ai-gateway",
                    f"Resource group '{resource_group_name}' created",
                    f"Failed to create the resource group '{resource_group_name}'")

# Deletes a specific resource based on its type
def delete_resource(resource, resource_group_name):
    resource_name = resource.get("name")
    resource_type = resource.get("type")
    resource_location = resource.get("location")

    print(f"🗑 Deleting {resource_type} '{resource_name}' in resource group '{resource_group_name}'...")

    # API Management
    if resource_type == "Microsoft.ApiManagement/service":
        output = run(f"az apim delete -n {resource_name} -g {resource_group_name} -y", f"API Management '{resource_name}' deleted", f"Failed to delete API Management '{resource_name}'")

        output = run(f"az apim deletedservice purge --service-name {resource_name} --location \"{resource_location}\"", f"API Management '{resource_name}' purged", f"Failed to purge API Management '{resource_name}'")

    # Cognitive Services
    elif resource_type == "Microsoft.CognitiveServices/accounts":
        output = run(f"az cognitiveservices account delete -g {resource_group_name} -n {resource_name}", f"Cognitive Services '{resource_name}' deleted", f"Failed to delete Cognitive Services '{resource_name}'")

        output = run(f"az cognitiveservices account purge -g {resource_group_name} -n {resource_name} -l \"{resource_location}\"", f"Cognitive Services '{resource_name}' purged", f"Failed to purge Cognitive Services '{resource_name}'")

    # Key Vault
    elif resource_type == "Microsoft.KeyVault/vaults":
        output = run(f"az keyvault delete -n {resource_name} -g {resource_group_name}", f"Key Vault '{resource_name}' deleted", f"Failed to delete Key Vault '{resource_name}'")

def get_deployment_output(output, output_property, output_label = '', secure = False) -> str:
    try:
        deployment_output = output.json_data['properties']['outputs'][output_property]['value']

        if output_label:
            if secure:
                print_info(f"{output_label}: ****{deployment_output[-4:]}")
            else:
                print_info(f"{output_label}: {deployment_output}")

        return str(deployment_output)
    except Exception as e:
        error = f"Failed to retrieve output property: '{output_property}'\nError: {e}"
        print_error(error)
        raise Exception(error)

def print_response(response):
    print("Response headers: ", response.headers)

    if (response.status_code == 200):
        print_ok(f"Status Code: {response.status_code}")
        data = json.loads(response.text)
        print(json.dumps(data, indent=4))
    else:
        print_warning(f"Status Code: {response.status_code}")
        print(response.text)

def print_response_code(response):
    # Check the response status code and apply formatting
    if 200 <= response.status_code < 300:
        status_code_str = f"{BOLD_GREEN}{response.status_code} - {response.reason}{RESET_FORMATTING}"
    elif response.status_code >= 400:
        status_code_str = f"{BOLD_RED}{response.status_code} - {response.reason}{RESET_FORMATTING}"
    else:
        status_code_str = str(response.status_code)

    # Print the response status with the appropriate formatting
    print(f"Response status: {status_code_str}")

def run(command, ok_message = '', error_message = '', print_output = False, print_command_to_run = True):
    if print_command_to_run:
        print_command(command)

    start_time = time.time()

    try:
        completed_process = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        output_text = completed_process.stdout
        success = completed_process.returncode == 0
    except subprocess.CalledProcessError as e:
        output_text = e.output.decode("utf-8")
        success = False

    minutes, seconds = divmod(time.time() - start_time, 60)

    print_message = print_ok if success else print_error

    if (ok_message or error_message):
        print_message(ok_message if success else error_message, output_text if not success or print_output  else "", f"[{int(minutes)}m:{int(seconds)}s]")

    return Output(success, output_text)

def create_bicep_params(policy_xml_filepath, parameters_filepath, bicep_parameters, replacements_list):
    # Read the specified policy XML file
    with open(policy_xml_filepath, 'r') as policy_xml_file:
        policy_template_xml = policy_xml_file.read()

    # Replace the placeholders in the policy XML with the actual values from the replacements_lists array
    for key, value in replacements_list:
        policy_template_xml = policy_template_xml.replace(key, str(value))

    # Set or update the policyXml parameter in the bicep parameters file
    bicep_parameters['parameters'].setdefault('policyXml', {})
    bicep_parameters['parameters']['policyXml']['value'] = policy_template_xml

    # Write the updated bicep parameters to the specified parameters file
    with open(parameters_filepath, 'w') as bicep_parameters_file:
        bicep_parameters_file.write(json.dumps(bicep_parameters))

    print(f"📝 Updated the policy XML in the bicep parameters file '{parameters_filepath}'")

    return bicep_parameters

def update_api_policy(subscription_id, resource_group_name, apim_service_name, api_id, policy_xml):
    # We first need to obtain an access token for the REST API
    output = run(f"az account get-access-token --resource https://management.azure.com/",
        f"Successfully obtained access token", f"Failed to obtain access token")

    if output.success and output.json_data:
        access_token = output.json_data['accessToken']

        print("Updating the API policy...")
        # https://learn.microsoft.com/en-us/rest/api/apimanagement/api-policy/create-or-update?view=rest-apimanagement-2024-06-01-preview
        url = f"https://management.azure.com/subscriptions/{subscription_id}/resourceGroups/{resource_group_name}/providers/Microsoft.ApiManagement/service/{apim_service_name}/apis/{api_id}/policies/policy?api-version=2024-06-01-preview"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {access_token}"
        }

        body = {
            "properties": {
                "format": "rawxml",
                "value": policy_xml
            }
        }

        response = requests.put(url, headers = headers, json = body)
        print_response_code(response)

def update_api_operation_policy(subscription_id, resource_group_name, apim_service_name, api_id, operation_id, policy_xml):
    # We first need to obtain an access token for the REST API
    output = run(f"az account get-access-token --resource https://management.azure.com/",
        f"Successfully obtained access token", f"Failed to obtain access token")

    if output.success and output.json_data:
        access_token = output.json_data['accessToken']

        print("Updating the API policy...")
        # https://learn.microsoft.com/en-us/rest/api/apimanagement/api-policy/create-or-update?view=rest-apimanagement-2024-06-01-preview
        url = f"https://management.azure.com/subscriptions/{subscription_id}/resourceGroups/{resource_group_name}/providers/Microsoft.ApiManagement/service/{apim_service_name}/apis/{api_id}/operations/{operation_id}/policies/policy?api-version=2024-06-01-preview"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {access_token}"
        }

        body = {
            "properties": {
                "format": "rawxml",
                "value": policy_xml
            }
        }

        response = requests.put(url, headers = headers, json = body)
        print_response_code(response)
