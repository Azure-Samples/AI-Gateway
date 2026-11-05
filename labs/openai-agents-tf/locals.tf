locals {
  location         = var.location != null ? var.location : azurerm_resource_group.rg.location
  resource_suffix  = random_string.suffix.result
  apim_logger_name = "apim-logger-${local.resource_suffix}"
  log_settings = {
    headers = ["Content-type", "User-agent", "x-ms-region", "x-ratelimit-remaining-tokens", "x-ratelimit-remaining-requests"]
    body    = { bytes = 8191 }
  }
  callback_url = azapi_resource_action.logic_app_callback.output["value"]
  base_path    = regex("^(https://[^?]+/triggers)(/|$)", local.callback_url)[0]
  sig          = regex("sig=([^&]+)", local.callback_url)[0]
  api-version  = "2016-10-01"
  sp           = regex("sp=([^&]+)", local.callback_url)[0]
  sv           = regex("sv=([^&]+)", local.callback_url)[0]
}