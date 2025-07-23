
resource_group_name     = "lab-backend-pool-load-balancing-tf"
resource_group_location = "westeurope"
apim_sku                = "BasicV2_1"
model_deployment_name   = "gpt-4o-mini"
model_name              = "gpt-4o-mini"
model_version           = "2024-07-18"
model_capacity          = "1"
model_api_version       = "2024-10-21"
aiservices_config       = {
  aiservices-uks = {
    name     = "foundry1",
    location = "uksouth",
    priority = 1
    weight   = ""
  },
  aiservices-swc = {
    name     = "foundry2",
    location = "swedencentral",
    priority = 2,
    weight   = 50
  },
  aiservices-frc = {
    name     = "foundry3",
    location = "francecentral",
    priority = 2,
    weight   = 50
  }
}

