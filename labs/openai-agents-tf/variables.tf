variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "resource_group_location" {
  type        = string
  description = "The location of the resource group."
  default     = "eastus"
}

variable "apim_resource_name" {
  type        = string
  description = "The name of the API Management resource."
  default     = "apim"
}

variable "apim_sku" {
  type        = string
  description = "The SKU of the API Management resource."
  default     = "Developer"
}

variable "openai_config" {
  description = "Configuration for OpenAI accounts"
  type = map(object({
    location = string
    name     = string
  }))
}

variable "openai_api_version" {
  type        = string
  description = "The API version for OpenAI Cognitive Service."
  default     = "2024-10-21"

}

variable "openai_sku" {
  type        = string
  description = "The SKU for OpenAI Cognitive Service."
  default     = "S0"
}

variable "openai_deployment_name" {
  type        = string
  description = "The name of the OpenAI deployment."
}

variable "openai_model_name" {
  type        = string
  description = "The name of the OpenAI model."
}

variable "openai_model_version" {
  type        = string
  description = "The version of the OpenAI model."
}

variable "openai_model_capacity" {
  type        = number
  description = "The capacity of the OpenAI model."
  default     = 1
}

variable "openai_api_spec_url" {
  type    = string
  default = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-10-21/inference.json"
}
variable "weather_api_path" {
  type        = string
  description = "The path for the Weather API."
  default     = "weatherservice"
}

variable "place_order_api_path" {
  type        = string
  description = "The path for the Place Order API."
  default     = "orderservice"
}

variable "product_catalog_api_path" {
  type        = string
  description = "The path for the Product Catalog API."
  default     = "catalogservice"
}

variable "location" {
  type        = string
  description = "The location for the resources."
  default     = "eastus"
}
