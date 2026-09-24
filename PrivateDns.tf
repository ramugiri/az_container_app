# Created here by default. If the platform team owns privatelink zones centrally,
# set create_private_dns_zones = false and pass existing_private_dns_zone_ids.
resource "azurerm_private_dns_zone" "zones" {
  for_each            = var.create_private_dns_zones ? local.private_dns_zone_names : {}
  name                = each.value
  resource_group_name = azurerm_resource_group.mcm.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "zones" {
  for_each              = azurerm_private_dns_zone.zones
  name                  = "pdnsl-${local.prefix}-${each.key}"
  resource_group_name   = azurerm_resource_group.mcm.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.mcm.id
  registration_enabled  = false
  tags                  = local.common_tags
}
