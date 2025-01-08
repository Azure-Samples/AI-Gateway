# type: ignore

import json

backend_id = "openai-backend-pool" if len(openai_resources) > 1 else openai_resources[0].get("name")

with open("policy.xml", 'r') as policy_xml_file:
    policy_xml = policy_xml_file.read()

    if "{backend-id}" in policy_xml:
        policy_xml = policy_xml.replace("{backend-id}", backend_id)

    if "{aad-client-application-id}" in policy_xml:
        policy_xml = policy_xml.replace("{aad-client-application-id}", client_id)

    if "{aad-tenant-id}" in policy_xml:
        policy_xml = policy_xml.replace("{aad-tenant-id}", tenant_id)

    policy_xml_file.close()
open("policy-updated.xml", 'w').write(policy_xml)

bicep_parameters = {
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "openAIConfig": { "value": openai_resources },
        "openAIDeploymentName": { "value": openai_deployment_name },
        "openAIModelName": { "value": openai_model_name },
        "openAIModelVersion": { "value": openai_model_version },
        "openAIAPIVersion": { "value": openai_api_version }
    }
}

with open('params.json', 'w') as bicep_parameters_file:
    bicep_parameters_file.write(json.dumps(bicep_parameters))

! az deployment group create --name {deployment_name} --resource-group {resource_group_name} --template-file "main.bicep" --parameters "params.json"
