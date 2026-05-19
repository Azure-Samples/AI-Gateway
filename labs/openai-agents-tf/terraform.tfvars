
resource_group_name     = "lab-openai-agents-tf"
resource_group_location = "uksouth"
apim_sku                = "Basicv2"
openai_deployment_name  = "gpt-4o-mini"
openai_model_name       = "gpt-4o-mini"
openai_model_version    = "2024-07-18"
openai_model_capacity   = "8"
openai_api_version      = "2024-10-21"
openai_config = {
  openai-1 = {
    name     = "openai1",
    location = "uksouth",
  }
}

