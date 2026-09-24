# Q2 / review point 1: the sync currently runs on ALL three pods every 15 minutes.
# A scheduled ACA Job with parallelism = 1 guarantees a single execution per cycle -
# no leader election or distributed lock needed in application code.
resource "azurerm_container_app_job" "sync" {
  name                         = local.names.aca_sync_job
  location                     = azurerm_resource_group.mcm.location
  resource_group_name          = azurerm_resource_group.mcm.name
  container_app_environment_id = azurerm_container_app_environment.mcm.id
  workload_profile_name        = "Consumption"
  replica_timeout_in_seconds   = 600
  replica_retry_limit          = 1
  tags                         = local.common_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = local.acr_login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  schedule_trigger_config {
    cron_expression          = var.sync_cron_expression
    parallelism              = 1
    replica_completion_count = 1
  }

  secret {
    name                = "psql-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.psql_connection_string.versionless_id
    identity            = azurerm_user_assigned_identity.app.id
  }

  template {
    container {
      name    = "sync"
      image   = local.images.sync_job
      command = local.placeholder ? null : var.sync_job_command
      cpu     = 0.5
      memory  = "1Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "psql-connection-string"
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.mcm.connection_string
      }
      env {
        name  = "FILES_MOUNT_PATH"
        value = "/mnt/conobs"
      }

      volume_mounts {
        name = "conobs"
        path = "/mnt/conobs"
      }
    }

    volume {
      name         = "conobs"
      storage_name = azurerm_container_app_environment_storage.conobs.name
      storage_type = "AzureFile"
    }
  }

  depends_on = [
    azurerm_role_assignment.app_acr_pull,
    azurerm_role_assignment.app_kv_secrets,
  ]
}
