import os
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

def load_secrets_from_keyvault(vault_url: str):
    """Load secrets from Azure Key Vault and set as environment variables"""
    credential = DefaultAzureCredential()
    kv_client = SecretClient(vault_url=vault_url, credential=credential)
    
    secret_names = [
        "MCP-SERVER-URL",
        "MCP-SERVER-LABEL", 
        "AZURE-AI-PROJECT-ENDPOINT",
        "AZURE-AI-MODEL-DEPLOYMENT-NAME"
    ]
    
    print("Loading secrets from Key Vault...")
    for secret_name in secret_names:
        try:
            secret = kv_client.get_secret(secret_name)
            env_var_name = secret_name.replace("-", "_")
            os.environ[env_var_name] = secret.value
            print(f"✅ Loaded: {env_var_name}")
        except Exception as e:
            print(f"❌ Failed to load {secret_name}: {e}")
    
    print("Environment variables loaded successfully!")
