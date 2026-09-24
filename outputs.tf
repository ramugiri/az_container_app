output "resource_group_name" {
  description = "Resource group holding all MCM resources"
  value       = azurerm_resource_group.mcm.name
}

output "aca_environment_static_ip" {
  description = "Internal load balancer IP of the ACA environment - give this to the platform team for the App Gateway backend pool"
  value       = azurerm_container_app_environment.mcm.static_ip_address
}

output "aca_environment_default_domain" {
  description = "Auto-created private DNS domain of the ACA environment"
  value       = azurerm_container_app_environment.mcm.default_domain
}

output "frontend_fqdn" {
  description = "Frontend internal FQDN (App Gateway backend / host header)"
  value       = azurerm_container_app.frontend.ingress[0].fqdn
}

output "service_fqdn" {
  description = "Service internal FQDN"
  value       = azurerm_container_app.service.ingress[0].fqdn
}

output "aca_subnet_id" {
  description = "ACA infrastructure subnet - the source scope for firewall rules and any platform-applied route table"
  value       = azurerm_subnet.aca.id
}

output "aca_subnet_prefix" {
  description = "ACA subnet CIDR - give this to the network team as the source for on-prem and egress firewall rules"
  value       = var.subnet_prefixes.aca
}

output "psql_fqdn" {
  description = "PostgreSQL Flexible Server FQDN (resolves privately)"
  value       = azurerm_postgresql_flexible_server.mcm.fqdn
}

output "psql_database_name" {
  value = azurerm_postgresql_flexible_server_database.mcm.name
}

output "storage_account_name" {
  value = azurerm_storage_account.mcm.name
}

output "file_share_name" {
  value = azurerm_storage_share.conobs.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.mcm.vault_uri
}

output "acr_login_server" {
  value = local.acr_login_server
}

output "app_identity_client_id" {
  description = "Client ID of the shared user-assigned identity used by the apps and job"
  value       = azurerm_user_assigned_identity.app.client_id
}
