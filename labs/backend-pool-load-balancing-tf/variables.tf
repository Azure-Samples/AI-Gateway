variable "resource_group_name" {
  type    = string
  default = "lab-backend-pool-load-balancing-terraform"
}

variable "resource_group_location" {
  type    = string
  default = "westeurope"
}

variable "aiservices_backend_pool_name" {
  type    = string
  default = "aiservices-backend-pool"
}

variable "aiservices_config" {
  default = {
    aiservices-uks = {
      name     = "foundry1",
      location = "uksouth",
      priority = 1,
      weight   = 100
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
}

variable "model_deployment_name" {
  type    = string
  default = "gpt-4o-mini"
}

variable "aiservices_sku" {
  type    = string
  default = "S0"
}

variable "model_name" {
  type    = string
  default = "gpt-4o-mini"
}

variable "model_version" {
  type    = string
  default = "2024-07-18"
}

variable "model_capacity" {
  type    = number
  default = 1
}

variable "model_api_spec_url" {
  type    = string
  default = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-10-21/inference.json"
}

variable "apim_resource_name" {
  type    = string
  default = "apim"
}

variable "apim_resource_location" {
  type    = string
  default = "westeurope" # APIM SKU StandardV2 is not yet supported in the region Sweden Central
}

variable "apim_sku" {
  type    = string
  default = "BasicV2"
}

variable "model_api_version" {
  type    = string
  default = "2024-10-21"
}