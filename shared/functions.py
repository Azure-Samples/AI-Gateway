# type: ignore

import datetime
import json
import subprocess
import traceback

# Logs the result of an action
def log(stdout, name, action):
    if stdout is None or stdout.startswith("ERROR"):
        print("👎🏻 ", name, " was NOT ", action, ": ", stdout)
    else:
        print("👍🏻 ", name, " was ", action, " ⌚ ", datetime.datetime.now().time())

# Cleans up resources associated with a deployment in a resource group
def cleanUpResources(deployment_name, resource_group_name):
    if not deployment_name or not resource_group_name:
        print("🚫 Missing required parameters for cleanup.")
        return

    try:
        print(f"🧹 Cleaning up deployment '{deployment_name}' resources in resource group '{resource_group_name}'...\n")

        # Show the deployment details
        deployment_stdout = run_az_cli(f"az deployment group show --name {deployment_name} -g {resource_group_name} -o json")
        if deployment_stdout is None:
            return

        deployment = json.loads(deployment_stdout)
        output_resources = deployment.get("properties", {}).get("outputResources", [])

        if output_resources is None:
            print(f"🚫 No output resources found for deployment '{deployment_name}'.")
            return

        # Iterate over the resources in the deployment
        for resource in output_resources:
            resource_id = resource.get("id")

            try:
                query = "\"{type:type, name:name, location:location}\""
                resource_stdout = run_az_cli(f"az resource show --id {resource_id} --query {query} -o json")
                if resource_stdout is None:
                    continue

                resource = json.loads(resource_stdout)

                # Delete the resource
                delete_resource(resource.get("type"), resource.get("name"), resource_group_name, resource.get("location"))

            except Exception as e:
                print(f"✌🏻 {resource_id} ignored due to error: {e}")
                traceback.print_exc()

        # Delete the resource group last
        command = f"az group delete --name {resource_group_name} -y"
        stdout = run_az_cli(command)
        log(stdout, resource_group_name, "deleted")
        log("\n🧹 Cleanup completed.")

    except Exception as e:
        print(f"An error occurred during cleanup: {e}")
        traceback.print_exc()

# Deletes a specific resource based on its type
def delete_resource(resource_type, resource_name, resource_group_name, resource_location=None):
    print(f"🗑 Deleting {resource_type} '{resource_name}' in resource group '{resource_group_name}'...")

    # API Management
    if resource_type == "Microsoft.ApiManagement/service":
        stdout = run_az_cli(f"az apim delete -n {resource_name} -g {resource_group_name} -y")
        log(stdout, resource_name, "deleted")

        stdout = run_az_cli(f"az apim deletedservice purge --service-name {resource_name} --location {resource_location}")
        log(stdout, resource_name, "purged")

    # Cognitive Services
    elif resource_type == "Microsoft.CognitiveServices/accounts":
        stdout = run_az_cli(f"az cognitiveservices account delete -g {resource_group_name} -n {resource_name}")
        log(stdout, resource_name, "deleted")

        stdout = run_az_cli(f"az cognitiveservices account purge -g {resource_group_name} -n {resource_name} -l {resource_location}")
        log(stdout, resource_name, "purged")

    # Key Vault
    elif resource_type == "Microsoft.KeyVault/vaults":
        stdout = run_az_cli(f"az keyvault delete -n {resource_name} -g {resource_group_name}")
        log(stdout, resource_name, "deleted")

# Runs an Azure CLI command and returns the output
def run_az_cli(command):
    try:
        result = subprocess.run(command, capture_output=True, text=True, shell=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ An error occurred:\n\n{e}\n\n{e.stderr}")
        return None
