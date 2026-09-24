# INF-03 / Q4: replaces the CISF SMB share //esri-shelf/ESRICONOBS (~930GB used).
resource "azurerm_storage_account" "mcm" {
  name                            = local.names.storage
  location                        = azurerm_resource_group.mcm.location
  resource_group_name             = azurerm_resource_group.mcm.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS" # Bronze SLA, no DR requirement (DR-01/DR-03)
  account_kind                    = "StorageV2"
  large_file_share_enabled        = true # required above 5TB and for big shares
  public_network_access_enabled   = false
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true # ACA storage mount requires an account key
  tags                            = local.common_tags
}

resource "azurerm_storage_share" "conobs" {
  name               = "esriconobs"
  storage_account_id = azurerm_storage_account.mcm.id
  quota              = var.file_share_quota_gb
  enabled_protocol   = "SMB"
}
