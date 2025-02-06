output "apim_resource_gateway_url" {
  value = azapi_resource.apim.output.properties.gatewayUrl
}

output "apim_subscription_key" {
  value     = azurerm_api_management_subscription.apim-api-subscription-openai.primary_key
  sensitive = true
}