# Dev and UAT share this file. For UAT:
#   terraform apply -var-file=non-prod.tfvars -var environment=uat

subscription_id = "288d2733-a09f-491f-93f0-02c33ffc7357" # TODO: non-prod subscription ID
environment     = "dev"
location        = "canadacentral"

vnet_address_space = ["10.100.24.0/22"] # TODO: network team allocation
subnet_prefixes = {
  aca  = "10.100.24.0/23"
  pep  = "10.100.26.0/27"
  psql = "10.100.26.32/28"
}

hub_vnet_id         = null
appgw_subnet_prefix = null

create_private_dns_zones = true

psql_sku_name          = "B_Standard_B2ms" # burstable is fine for non-prod
psql_storage_mb        = 65536
psql_version           = "16"
psql_high_availability = false

file_share_quota_gb = 1024

acr_name = "acrmcmdev001"

frontend_replicas = { min = 1, max = 2 }
service_replicas  = { min = 1, max = 2 }

alert_emails = {}

tags = {
  cost_centre = "TODO"
  criticality = "bronze"
}
