# On-prem footprint (Q1/Q6): frontend and service are built and deployed independently.
# Frontend 3 pods x 0.5 vCPU / 512MB; service 3 pods x 2 vCPU / 4GB at peak.
# ACA requires paired cpu/memory values, so 0.5 vCPU pairs with 1Gi.

resource "azurerm_container_app" "frontend" {
  name                         = local.names.aca_frontend
  container_app_environment_id = azurerm_container_app_environment.mcm.id
  resource_group_name          = azurerm_resource_group.mcm.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.common_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = local.acr_login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  # external_enabled = true means "exposed on the environment ingress".
  # The environment is internal, so this is still a private ILB address.
  ingress {
    external_enabled           = true
    target_port                = local.ports.frontend
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.frontend_replicas.min
    max_replicas = var.frontend_replicas.max

    container {
      name   = "frontend"
      image  = local.images.frontend
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.mcm.connection_string
      }
      env {
        name  = "SERVICE_BASE_URL"
        value = "https://${local.names.aca_service}"
      }

      dynamic "liveness_probe" {
        for_each = local.placeholder ? [] : [1]
        content {
          transport = "HTTP"
          port      = local.ports.frontend
          path      = "/health" # TODO: confirm probe path with the app team
        }
      }
    }

    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = 100
    }
  }

  depends_on = [azurerm_role_assignment.app_acr_pull]
}

resource "azurerm_container_app" "service" {
  name                         = local.names.aca_service
  container_app_environment_id = azurerm_container_app_environment.mcm.id
  resource_group_name          = azurerm_resource_group.mcm.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.common_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = local.acr_login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  ingress {
    external_enabled           = true
    target_port                = local.ports.service
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  # Key Vault references resolved at runtime by the user-assigned identity.
  secret {
    name                = "ppm-basic-auth"
    key_vault_secret_id = azurerm_key_vault_secret.ppm_basic_auth.versionless_id
    identity            = azurerm_user_assigned_identity.app.id
  }

  secret {
    name                = "psql-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.psql_connection_string.versionless_id
    identity            = azurerm_user_assigned_identity.app.id
  }

  template {
    min_replicas = var.service_replicas.min
    max_replicas = var.service_replicas.max

    container {
      name   = "service"
      image  = local.images.service
      cpu    = 2.0
      memory = "4Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.mcm.connection_string
      }
      env {
        name        = "DATABASE_URL"
        secret_name = "psql-connection-string"
      }
      env {
        name        = "PPM_BASIC_AUTH"
        secret_name = "ppm-basic-auth"
      }
      env {
        name  = "PPM_SOAP_URL"
        value = var.ppm_soap_url
      }
      env {
        name  = "FILES_MOUNT_PATH"
        value = "/mnt/conobs"
      }
      # Q2: the in-app interval timer must be off; the ACA Job owns the schedule.
      env {
        name  = "SYNC_JOB_ENABLED"
        value = "false"
      }

      volume_mounts {
        name = "conobs"
        path = "/mnt/conobs"
      }

      dynamic "liveness_probe" {
        for_each = local.placeholder ? [] : [1]
        content {
          transport = "HTTP"
          port      = local.ports.service
          path      = "/health" # TODO: confirm probe path with the app team
        }
      }
    }

    volume {
      name         = "conobs"
      storage_name = azurerm_container_app_environment_storage.conobs.name
      storage_type = "AzureFile"
    }

    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = 50
    }
  }

  depends_on = [
    azurerm_role_assignment.app_acr_pull,
    azurerm_role_assignment.app_kv_secrets,
  ]
}
