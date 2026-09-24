# REF-05: configs and secrets are already externalized; they move here.
resource "azurerm_key_vault" "mcm" {
  name                       = local.names.key_vault
  location                   = azurerm_resource_group.mcm.location
  resource_group_name        = azurerm_resource_group.mcm.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 30
  # Private-only, except that the vault is created open to the pipeline runner IP so
  # Terraform can seed the secrets below. After creation the pipeline opens the
  # firewall to its runner IP before each run and closes it again afterwards.
  public_network_access_enabled = length(var.deployer_ip_allowlist) > 0
  tags                          = local.common_tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.deployer_ip_allowlist
  }

  lifecycle {
    ignore_changes = [public_network_access_enabled, network_acls]
  }
}

# The pipeline identity needs to seed secrets.
resource "azurerm_role_assignment" "kv_deployer" {
  scope                = azurerm_key_vault.mcm.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "random_password" "psql_admin" {
  length  = 28
  special = true
  # Flexible Server rejects some characters in the admin password
  override_special = "!#%*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault_secret" "psql_admin_password" {
  name         = local.secret_names.psql_admin_password
  value        = random_password.psql_admin.result
  key_vault_id = azurerm_key_vault.mcm.id
  content_type = "password"
  depends_on   = [azurerm_role_assignment.kv_deployer]
}

resource "azurerm_key_vault_secret" "psql_connection_string" {
  name         = local.secret_names.psql_connection
  value        = "postgresql://${var.psql_admin_login}:${urlencode(random_password.psql_admin.result)}@${azurerm_postgresql_flexible_server.mcm.fqdn}:5432/${azurerm_postgresql_flexible_server_database.mcm.name}?sslmode=require"
  key_vault_id = azurerm_key_vault.mcm.id
  content_type = "connection-string"
  depends_on   = [azurerm_role_assignment.kv_deployer]
}

# PPM SOAP basic-auth credential (Q5 / review point 5).
# Terraform creates the secret so the container app can reference it on first apply;
# the REAL credential is set out-of-band by the app/PPM team and is never stored in
# state or tfvars. ignore_changes stops Terraform reverting it on later runs.
resource "azurerm_key_vault_secret" "ppm_basic_auth" {
  name         = local.secret_names.ppm_basic_auth
  value        = "PLACEHOLDER-SET-OUT-OF-BAND"
  key_vault_id = azurerm_key_vault.mcm.id
  content_type = "ppm basic auth - set manually"
  depends_on   = [azurerm_role_assignment.kv_deployer]

  lifecycle {
    ignore_changes = [value]
  }
}
