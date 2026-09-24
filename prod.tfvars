# Production  -  apply with: terraform apply -var-file=prod.tfvars

subscription_id = "00000000-0000-0000-0000-000000000000" # TODO: prod subscription ID
environment     = "prd"
location        = "canadacentral"

# TODO: CIDRs allocated by the network team. The aca subnet must be /23 or larger
# and cannot be resized after the ACA environment is created.
vnet_address_space = ["10.100.20.0/22"]
subnet_prefixes = {
  aca  = "10.100.20.0/23"
  pep  = "10.100.22.0/27"
  psql = "10.100.22.32/28"
}

hub_vnet_id         = null # TODO: hub VNet resource ID from the platform team
appgw_subnet_prefix = null # TODO: App Gateway subnet CIDR, to tighten the inbound NSG rule

# Platform team owns privatelink zones centrally? Then:
#   create_private_dns_zones      = false
#   existing_private_dns_zone_ids = { psql = "...", kv = "...", file = "...", acr = "..." }
create_private_dns_zones = true

# SKU / HA are TBD pending architecture sign-off (review point 7).
psql_sku_name          = "GP_Standard_D2ds_v5" # 2 vCore / 8GB
psql_storage_mb        = 65536
psql_version           = "16"
psql_high_availability = false # discovery: NO HA / NO DR (Bronze)

file_share_quota_gb = 2048 # current CISF usage ~930GB

acr_name = "acrmcmprd001" # TODO: confirm naming standard or switch to a shared ACR

frontend_replicas = { min = 1, max = 3 }
service_replicas  = { min = 1, max = 3 }

alert_emails = {
  as3-support = "AS3-MobileAppSupport@bchydro.com" # TODO: confirm DL with the OBS-04 owner
}

tags = {
  cost_centre = "TODO"
  criticality = "bronze"
}
