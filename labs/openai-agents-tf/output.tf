output "application_insights_instrumentation_key" {
  value     = azurerm_application_insights.appinsights.instrumentation_key
  sensitive = true
}

output "api_management_gateway_url" {
  value = azapi_resource.apim.output.properties.gatewayUrl
}

output "openai_subscription_key" {
  value     = azurerm_api_management_subscription.openai-subscription.primary_key
  sensitive = true
}

output "tools_subscription_key" {
  value     = azurerm_api_management_subscription.tools-apis-subscription.primary_key
  sensitive = true
}
