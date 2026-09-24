# One user-assigned identity shared by both container apps and the job.
#
# Why user-assigned rather than system-assigned: a container app that references
# Key Vault secrets must already have vault access AT CREATION TIME. With
# system-assigned identities the identity does not exist until the app is created,
# so the first apply fails. Creating the identity up front and granting its roles
# before the apps breaks that circular dependency.
resource "azurerm_user_assigned_identity" "app" {
  name                = local.names.uami
  location            = azurerm_resource_group.mcm.location
  resource_group_name = azurerm_resource_group.mcm.name
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = local.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_role_assignment" "app_kv_secrets" {
  scope                = azurerm_key_vault.mcm.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_role_assignment" "app_storage_smb" {
  scope                = azurerm_storage_account.mcm.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
