# Standalone private endpoint resources (same pattern as az-ecsi-app-infra).
# PostgreSQL is NOT here: it is VNet-injected via subnet delegation instead.
resource "azurerm_private_endpoint" "kv" {
  name                = "pep-kv-${local.prefix}-001"
  location            = azurerm_resource_group.mcm.location
  resource_group_name = azurerm_resource_group.mcm.name
  subnet_id           = azurerm_subnet.pep.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-kv-${local.prefix}"
    private_connection_resource_id = azurerm_key_vault.mcm.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [local.private_dns_zone_ids["kv"]]
  }
}

resource "azurerm_private_endpoint" "file" {
  name                = "pep-file-${local.prefix}-001"
  location            = azurerm_resource_group.mcm.location
  resource_group_name = azurerm_resource_group.mcm.name
  subnet_id           = azurerm_subnet.pep.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-file-${local.prefix}"
    private_connection_resource_id = azurerm_storage_account.mcm.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [local.private_dns_zone_ids["file"]]
  }
}

resource "azurerm_private_endpoint" "acr" {
  count               = var.create_acr ? 1 : 0
  name                = "pep-acr-${local.prefix}-001"
  location            = azurerm_resource_group.mcm.location
  resource_group_name = azurerm_resource_group.mcm.name
  subnet_id           = azurerm_subnet.pep.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-acr-${local.prefix}"
    private_connection_resource_id = azurerm_container_registry.mcm[0].id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [local.private_dns_zone_ids["acr"]]
  }
}
