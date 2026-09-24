# Dedicated registry, or set create_acr = false to consume a shared platform ACR.
resource "azurerm_container_registry" "mcm" {
  count                         = var.create_acr ? 1 : 0
  name                          = var.acr_name
  location                      = azurerm_resource_group.mcm.location
  resource_group_name           = azurerm_resource_group.mcm.name
  sku                           = "Premium" # Premium is required for private endpoints
  admin_enabled                 = false
  public_network_access_enabled = false
  network_rule_bypass_option    = "AzureServices"
  tags                          = local.common_tags
}
