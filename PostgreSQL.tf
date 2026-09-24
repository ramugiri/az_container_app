# DB-10: target PaaS is PostgreSQL Flexible Server, VNet-injected into a delegated subnet.
# ~25GB, not IOPS sensitive (DB-03), nightly 7-day rolling backup (DB-04), port 5432 (INF-04).
# SKU and HA are variable-driven and marked TBD pending architecture sign-off.
resource "azurerm_postgresql_flexible_server" "mcm" {
  name                          = local.names.psql_server
  location                      = azurerm_resource_group.mcm.location
  resource_group_name           = azurerm_resource_group.mcm.name
  version                       = var.psql_version
  sku_name                      = var.psql_sku_name
  storage_mb                    = var.psql_storage_mb
  administrator_login           = var.psql_admin_login
  administrator_password        = random_password.psql_admin.result
  backup_retention_days         = var.psql_backup_retention_days
  geo_redundant_backup_enabled  = false
  delegated_subnet_id           = azurerm_subnet.psql.id
  private_dns_zone_id           = local.private_dns_zone_ids["psql"]
  public_network_access_enabled = false
  zone                          = var.psql_zone
  tags                          = local.common_tags

  dynamic "high_availability" {
    for_each = var.psql_high_availability ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.psql_standby_zone
    }
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.zones,
    azurerm_subnet_network_security_group_association.pep,
  ]

  lifecycle {
    # Azure may relocate the server's zone; do not fight it on later plans.
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "mcm" {
  name      = "mcm"
  server_id = azurerm_postgresql_flexible_server.mcm.id
  collation = "en_US.utf8"
  charset   = "UTF8"

  lifecycle {
    prevent_destroy = true
  }
}

# Require TLS from clients
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.mcm.id
  value     = "on"
}
