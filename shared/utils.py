import os, subprocess, datetime, time, json, traceback

print_info = lambda message: print("👉🏽 \x1b[1;34m", message, "\x1b[0m")
print_message = lambda message, output='', duration='': print("👉🏽 \x1b[1;32m", message, "\x1b[0m⌚", datetime.datetime.now().time(), duration, "\n" if output else "", output)
print_ok = lambda message, output='', duration='': print("✅ \x1b[1;32m", message, "\x1b[0m⌚", datetime.datetime.now().time(), duration, "\n" if output else "", output)
print_error = lambda message, output='', duration='': print("⛔ \x1b[1;31m", message, "\x1b[0m⌚", datetime.datetime.now().time(), duration, "\n" if output else "", output)
print_warning = lambda message, output='', duration='': print("⚠️ \x1b[1;33m", message, "\x1b[0m⌚", datetime.datetime.now().time(), duration, "\n" if output else "", output)
print_command = lambda command ='': print("⚙️ \x1b[1;34m Running: ", command, "\x1b[0m")
class Output(object):
    def __init__(self, success, text):
        self.success = success
        self.text = text
        try:
            self.json_data = json.loads(text)
        except:
            self.json_data = None
def run(command, ok_message = '', error_message = '', print_output = False, print_command_to_run = True):
    if print_command_to_run:
        print_command(command)
    start_time = time.time()
    try:
        output_text = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT).decode("utf-8")
        success = True
    except subprocess.CalledProcessError as e:
        output_text = e.output.decode("utf-8")
        success = False
    minutes, seconds = divmod(time.time() - start_time, 60)
    print_message = print_ok if success else print_error
    if (ok_message or error_message):
        print_message(ok_message if success else error_message, output_text if not success or print_output  else "", f"[{int(minutes)}m:{int(seconds)}s]")
    return Output(success, output_text)

def create_resource_group(create_resources, resource_group_name, resource_group_location):
    if not resource_group_name:
        print_warning('Please specify the resource group name')
    else:
        output = run(f"az group show --name {resource_group_name}")
        if create_resources:    
            if output.success:
                print_info(f"Using existing resource group '{resource_group_name}'")
            else:
                output = run(f"az group create --name {resource_group_name} --location {resource_group_location}", 
                                        f"Resource group '{resource_group_name}' created", 
                                        f"Failed to create the resource group '{resource_group_name}'")
        else:
            if output.success:
                print_info(f"Using resource group '{resource_group_name}'")
            else:
                print_error(f"Resource group '{resource_group_name}' does not exist")

def get_deployment_output(output, output_property, output_label = '', secure = False):
    try:       
        deployment_output = output.json_data['properties']['outputs'][output_property]['value'] 
        if output_label:
            if secure:
                print_info(f"{output_label}: ****{deployment_output[-4:]}")
            else:
                print_info(f"{output_label}: {deployment_output}")
        return deployment_output
    except:
        print_error(f"Failed to retieve output property: '{output_property}'")
        return None
    
def print_response(response):
    print("Response headers: ", response.headers)
    if (response.status_code == 200):
        print_ok(f"Status Code: {response.status_code}")
        data = json.loads(response.text)
        print(json.dumps(data, indent=4))
    else:
        print_warning(f"Status Code: {response.status_code}")
        print(response.text)

# Cleans up resources associated with a deployment in a resource group
def cleanup_resources(deployment_name, resource_group_name = None):
    if not deployment_name:
        print_error("Missing deployment name parameter.")
        return

    if not resource_group_name:
        resource_group_name = f"lab-{deployment_name}"

    try:
        print_message(f"🧹 Cleaning up deployment '{deployment_name}' resources in resource group '{resource_group_name}'...")

        # Show the deployment details
        output = run(f"az deployment group show --name {deployment_name} -g {resource_group_name} -o json", "Deployment retrieved", "Failed to retrieve the deployment")
        if output.success and output.json_data:
            resources = output.json_data.get("properties", {}).get("outputResources", [])
            if resources is None:
                print_error(f"No resources found for deployment '{deployment_name}'.")
                return
            else:
                i = 1

                # Iterate over the resources in the deployment
                for resource in resources:
                    print(f"\n🔍  Processing resource {i}/{len(resources)}...")
                    resource_id = resource.get("id")
                    i+=1

                    try:
                        output = run(f"az resource show --id {resource_id} --query \"{{type:type, name:name, location:location}}\" -o json")
                        if output.success and output.json_data:
                            delete_resource(output.json_data, resource_group_name)

                    except Exception as e:
                        print(f"✌🏻 {resource_id} ignored due to error: {e}")
                        traceback.print_exc()

        # Delete the resource group last
        output = run(f"az group delete --name {resource_group_name} -y", f"Resource group '{resource_group_name}' deleted", f"Failed to delete resource group '{resource_group_name}'")

        print_message("🧹 Cleanup completed.")

    except Exception as e:
        print(f"An error occurred during cleanup: {e}")
        traceback.print_exc()

# Deletes a specific resource based on its type
def delete_resource(resource, resource_group_name):
    resource_name = resource.get("name")
    resource_type = resource.get("type")
    resource_location = resource.get("location")

    print(f"🗑  Deleting {resource_type} '{resource_name}' in resource group '{resource_group_name}'...")

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





