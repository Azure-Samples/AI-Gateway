# type: ignore

import datetime
import json
import subprocess
import traceback

# Cleans up resources associated with a deployment in a resource group
def cleanUpResources(deployment_name, resource_group_name = None):
    if not deployment_name:
        print("🚫 Missing deployment name parameter.")
        return

    if not resource_group_name:
        resource_group_name = f"lab-{deployment_name}"

    try:
        print(f"🧹 Cleaning up deployment '{deployment_name}' resources in resource group '{resource_group_name}'...")

        # Show the deployment details
        stdout = run_az_cli(f"az deployment group show --name {deployment_name} -g {resource_group_name} -o json")
        if stdout is None:
            return

        deployment = json.loads(stdout)
        resources = deployment.get("properties", {}).get("outputResources", [])

        if resources is None:
            print(f"🚫 No resources found for deployment '{deployment_name}'.")
            return

        i = 1

        # Iterate over the resources in the deployment
        for resource in resources:
            print(f"\n🔍 Processing resource {i}/{len(resources)}...")
            resource_id = resource.get("id")
            i+=1

            try:
                stdout = run_az_cli(f"az resource show --id {resource_id} --query \"{{type:type, name:name, location:location}}\" -o json")
                if stdout is None:
                    continue

                delete_resource(json.loads(stdout), resource_group_name)

            except Exception as e:
                print(f"✌🏻 {resource_id} ignored due to error: {e}")
                traceback.print_exc()

        # Delete the resource group last
        print(f"\n🗑 Deleting resource group '{resource_group_name}'...")
        stdout = run_az_cli(f"az group delete --name {resource_group_name} -y")
        log(stdout, resource_group_name, "deleted")
        print("\n🧹 Cleanup completed.")

    except Exception as e:
        print(f"An error occurred during cleanup: {e}")
        traceback.print_exc()

# Deletes a specific resource based on its type
def delete_resource(resource, resource_group_name):
    resource_name = resource.get("name")
    resource_type = resource.get("type")
    resource_location = resource.get("location")

    print(f"🗑 Deleting {resource_type} '{resource_name}' in resource group '{resource_group_name}'...")

    # API Management
    if resource_type == "Microsoft.ApiManagement/service":
        stdout = run_az_cli(f"az apim delete -n {resource_name} -g {resource_group_name} -y")
        log(stdout, resource_name, "deleted")

        stdout = run_az_cli(f"az apim deletedservice purge --service-name {resource_name} --location \"{resource_location}\"")
        log(stdout, resource_name, "purged")

    # Cognitive Services
    elif resource_type == "Microsoft.CognitiveServices/accounts":
        stdout = run_az_cli(f"az cognitiveservices account delete -g {resource_group_name} -n {resource_name}")
        log(stdout, resource_name, "deleted")

        stdout = run_az_cli(f"az cognitiveservices account purge -g {resource_group_name} -n {resource_name} -l \"{resource_location}\"")
        log(stdout, resource_name, "purged")

    # Key Vault
    elif resource_type == "Microsoft.KeyVault/vaults":
        stdout = run_az_cli(f"az keyvault delete -n {resource_name} -g {resource_group_name}")
        log(stdout, resource_name, "deleted")

# Logs the result of an action
def log(stdout, name, action):
    if stdout is None or stdout.startswith("ERROR"):
        print(f"👎🏻 {name} was NOT {action}: {stdout}")
    else:
        print(f"👍🏻 {name} was {action}: ⌚ {datetime.datetime.now().time()}")

# Runs an Azure CLI command and returns the output
def run_az_cli(command):
    try:
        result = subprocess.run(command, capture_output=True, text=True, shell=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        # It's not unusual to encounter a ResourceNotFound error. If that happens, just return and move on.
        if 'ResourceNotFound' in e.stderr:
            print("🚫 Resource not found.")
        else:
            print(f"❌ An error occurred:\n\n{e}\n\n{e.stderr}")

    return None
