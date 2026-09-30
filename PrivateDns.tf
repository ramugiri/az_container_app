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

# The ACA environment's own domain. An internal environment gets no DNS for its app
# FQDNs, so without this zone ca-mcm-<env>-*.<default_domain> does not resolve inside
# the VNet. Every name points at the environment's internal load balancer; ACA's
# ingress then routes by host name to the right app.
resource "azurerm_private_dns_zone" "aca_env" {
  name                = azurerm_container_app_environment.mcm.default_domain
  resource_group_name = azurerm_resource_group.mcm.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_a_record" "aca_env_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.aca_env.name
  resource_group_name = azurerm_resource_group.mcm.name
  ttl                 = 300
  records             = [azurerm_container_app_environment.mcm.static_ip_address]
}

resource "azurerm_private_dns_a_record" "aca_env_apex" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.aca_env.name
  resource_group_name = azurerm_resource_group.mcm.name
  ttl                 = 300
  records             = [azurerm_container_app_environment.mcm.static_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "aca_env" {
  name                  = "pdnsl-${local.prefix}-aca-env"
  resource_group_name   = azurerm_resource_group.mcm.name
  private_dns_zone_name = azurerm_private_dns_zone.aca_env.name
  virtual_network_id    = azurerm_virtual_network.mcm.id
  registration_enabled  = false
  tags                  = local.common_tags
}
