variable "resource_group_name" {
  type        = string
  default     = "lab-backend-pool-load-balancing-terraform"
}

variable "resource_group_location" {
  type        = string
  default     = "westeurope"
}

variable "openai_backend_pool_name" {
  type        = string
  default     = "openai-backend-pool"
}

variable "openai_config" {
  default = {
    openai-uks = {
      name     = "openai1",
      location = "uksouth",
      priority = 1,
      weight   = 100
    },
    openai-swc = {
      name     = "openai2",
      location = "swedencentral",
      priority = 2,
      weight   = 50
    },
    openai-frc = {
      name     = "openai3",
      location = "francecentral",
      priority = 2,
      weight   = 50
    }
  }
}

variable "openai_deployment_name" {
  type        = string
  default     = "gpt-4o"
}

variable "openai_sku" {
  type        = string
  default     = "S0"
}

variable "openai_model_name" {
  type        = string
  default     = "gpt-4o"
}

variable "openai_model_version" {
  type        = string
  default     = "2024-08-06"
}

variable "openai_model_capacity" {
  type        = number
  default     = 8
}

variable "openai_api_spec_url" {
  type        = string
  default     = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-10-21/inference.json"
}

variable "apim_resource_name" {
  type        = string
  default     = "apim"
}

variable "apim_resource_location" {
  type        = string
  default     = "westeurope" # APIM SKU StandardV2 is not yet supported in the region Sweden Central
}

variable "apim_sku" {
  type        = string
  default     = "BasicV2"
}

variable "openai_api_version" {
  type        = string
  default     = "2024-10-21"
}