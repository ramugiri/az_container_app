# internal_load_balancer_enabled = true provisions the internal Standard LB that
# fronts the environment. Its private IP is the App Gateway backend target.
# NOTE: this flag and infrastructure_subnet_id are immutable - changing either
# forces replacement of the environment and every app in it.
resource "azurerm_container_app_environment" "mcm" {
  name                           = local.names.aca_env
  location                       = azurerm_resource_group.mcm.location
  resource_group_name            = azurerm_resource_group.mcm.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.mcm.id
  infrastructure_subnet_id       = azurerm_subnet.aca.id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = false # Bronze: no HA requirement
  tags                           = local.common_tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

# Mounts the Azure Files share so container apps can bind it as a volume.
resource "azurerm_container_app_environment_storage" "conobs" {
  name                         = "conobs"
  container_app_environment_id = azurerm_container_app_environment.mcm.id
  account_name                 = azurerm_storage_account.mcm.name
  share_name                   = azurerm_storage_share.conobs.name
  access_key                   = azurerm_storage_account.mcm.primary_access_key
  access_mode                  = "ReadWrite"
}
