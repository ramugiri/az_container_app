resource "azurerm_resource_group" "mcm" {
  name     = local.names.resource_group
  location = var.location
  tags     = local.common_tags
}
