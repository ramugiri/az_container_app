locals {
  app    = "mcm"
  prefix = "${local.app}-${var.environment}"

  common_tags = merge({
    application = "Mobile Construction Management"
    app_code    = "MADG"
    wave        = "wave1"
    environment = var.environment
    managed_by  = "terraform"
    repo        = "az-mcm-app-infra"
  }, var.tags)

  names = {
    resource_group = "rg-${local.prefix}-canadacentral-001"
    vnet           = "vnet-${local.prefix}-canadacentral-001"
    snet_aca       = "snet-${local.prefix}-aca-01"
    snet_pep       = "snet-${local.prefix}-pep-01"
    snet_psql      = "snet-${local.prefix}-psql-01"
    nsg_aca        = "nsg-${local.prefix}-aca-01"
    nsg_pep        = "nsg-${local.prefix}-pep-01"
    uami           = "id-${local.prefix}-app-01"
    log_analytics  = "log-${local.prefix}-01"
    app_insights   = "appi-${local.prefix}-01"
    action_group   = "ag-${local.prefix}-as3"
    key_vault      = "kv-${local.prefix}-01"
    storage        = "st${local.app}${var.environment}conobs01"
    psql_server    = "psql-${local.prefix}-01"
    aca_env        = "cae-${local.prefix}-01"
    aca_frontend   = "ca-${local.prefix}-frontend"
    aca_service    = "ca-${local.prefix}-service"
    aca_sync_job   = "caj-${local.prefix}-sync"
  }

  # ACR is either created here or consumed from the platform
  acr_id           = var.create_acr ? azurerm_container_registry.mcm[0].id : var.existing_acr_id
  acr_login_server = var.create_acr ? azurerm_container_registry.mcm[0].login_server : var.existing_acr_login_server

  # Placeholder images let the first apply succeed before the app images exist in ACR.
  # The quickstart images listen on port 80 and have no /health endpoint.
  placeholder = var.use_placeholder_images
  images = {
    frontend = local.placeholder ? "mcr.microsoft.com/k8se/quickstart:latest" : "${local.acr_login_server}/${var.frontend_image}"
    service  = local.placeholder ? "mcr.microsoft.com/k8se/quickstart:latest" : "${local.acr_login_server}/${var.service_image}"
    sync_job = local.placeholder ? "mcr.microsoft.com/k8se/quickstart-jobs:latest" : "${local.acr_login_server}/${var.sync_job_image}"
  }
  ports = {
    frontend = local.placeholder ? 80 : 8080
    service  = local.placeholder ? 80 : 3000
  }

  # privatelink zones: created locally or supplied by the platform team
  private_dns_zone_names = {
    psql = "privatelink.postgres.database.azure.com"
    kv   = "privatelink.vaultcore.azure.net"
    file = "privatelink.file.core.windows.net"
    acr  = "privatelink.azurecr.io"
  }

  private_dns_zone_ids = var.create_private_dns_zones ? {
    for k, z in azurerm_private_dns_zone.zones : k => z.id
  } : var.existing_private_dns_zone_ids

  # Key Vault secret names (referenced by the container apps)
  secret_names = {
    psql_admin_password = "psql-admin-password"
    psql_connection     = "psql-connection-string"
    ppm_basic_auth      = "ppm-basic-auth"
  }
}
