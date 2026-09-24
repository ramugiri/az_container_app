resource "azurerm_virtual_network" "mcm" {
  name                = local.names.vnet
  location            = azurerm_resource_group.mcm.location
  resource_group_name = azurerm_resource_group.mcm.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags
}

# Spoke -> hub. The hub -> spoke peering is applied by the platform team.
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count                        = var.hub_vnet_id == null ? 0 : 1
  name                         = "peer-${local.prefix}-to-hub"
  resource_group_name          = azurerm_resource_group.mcm.name
  virtual_network_name         = azurerm_virtual_network.mcm.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  use_remote_gateways          = true # egress to on-prem PPM / SMTP via the hub ExpressRoute gateway
}
