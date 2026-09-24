##############################
# Subscription / environment
##############################
variable "subscription_id" {
  description = "Target Azure subscription ID"
  type        = string
}

variable "environment" {
  description = "Deployment environment: dev, uat or prd"
  type        = string
  validation {
    condition     = contains(["dev", "uat", "prd"], var.environment)
    error_message = "environment must be one of dev, uat, prd."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "canadacentral"
}

variable "tags" {
  description = "Additional resource tags merged over the common set"
  type        = map(string)
  default     = {}
}

##############################
# Networking
##############################
variable "vnet_address_space" {
  description = "Address space for the MCM spoke VNet (allocated by the network team)"
  type        = list(string)
}

variable "subnet_prefixes" {
  description = "Subnet CIDRs. aca must be /23 or larger and is immutable once the ACA environment exists."
  type = object({
    aca  = string # delegated to Microsoft.App/environments
    pep  = string # private endpoints
    psql = string # delegated to Microsoft.DBforPostgreSQL/flexibleServers
  })
}

variable "hub_vnet_id" {
  description = "Resource ID of the platform hub VNet for peering. Null skips peering (hub side is applied by the platform team)."
  type        = string
  default     = null
}

variable "appgw_subnet_prefix" {
  description = "Platform App Gateway subnet CIDR, used to scope the inbound NSG rule. Null falls back to VirtualNetwork."
  type        = string
  default     = null
}

variable "create_private_dns_zones" {
  description = "Create privatelink DNS zones in this spoke. Set false if the platform team manages them centrally in the hub (then supply existing_private_dns_zone_ids)."
  type        = bool
  default     = true
}

variable "existing_private_dns_zone_ids" {
  description = "Platform-managed privatelink zone IDs, used when create_private_dns_zones = false. Keys: psql, kv, file, acr."
  type        = map(string)
  default     = {}
}

##############################
# PostgreSQL  (SKU / HA = TBD per architecture review)
##############################
variable "psql_sku_name" {
  description = "PostgreSQL Flexible Server SKU. TBD pending sizing sign-off; DB is ~25GB and not IOPS sensitive."
  type        = string
  default     = "B_Standard_B2ms"
}

variable "psql_storage_mb" {
  description = "PostgreSQL storage in MB (minimum 32768)"
  type        = number
  default     = 65536
}

variable "psql_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "psql_admin_login" {
  description = "PostgreSQL administrator username (password is generated and stored in Key Vault)"
  type        = string
  default     = "mcmadmin"
}

variable "psql_backup_retention_days" {
  description = "PITR retention. Current on-prem behaviour is a nightly 7-day rolling backup."
  type        = number
  default     = 7
}

variable "psql_high_availability" {
  description = "Zone-redundant HA. Discovery says NO HA / NO DR (Bronze), so default is off. TBD pending review."
  type        = bool
  default     = false
}

variable "psql_zone" {
  description = "Availability zone for the primary"
  type        = string
  default     = "1"
}

variable "psql_standby_zone" {
  description = "Standby zone, used only when psql_high_availability = true"
  type        = string
  default     = "2"
}

##############################
# Storage (replaces CISF SMB share)
##############################
variable "file_share_quota_gb" {
  description = "Azure Files share quota in GB. Current CISF usage is ~930GB."
  type        = number
  default     = 2048
}

##############################
# Containers
##############################
variable "acr_name" {
  description = "Globally unique ACR name, alphanumeric only. Set create_acr = false to consume a shared platform registry instead."
  type        = string
}

variable "create_acr" {
  description = "Create a dedicated ACR. False consumes an existing registry via existing_acr_id / existing_acr_login_server."
  type        = bool
  default     = true
}

variable "existing_acr_id" {
  description = "Resource ID of a shared ACR, used when create_acr = false"
  type        = string
  default     = null
}

variable "existing_acr_login_server" {
  description = "Login server of a shared ACR, used when create_acr = false"
  type        = string
  default     = null
}

variable "frontend_image" {
  description = "Frontend image as repo:tag, appended to the ACR login server"
  type        = string
  default     = "madg-construction-observations:latest"
}

variable "service_image" {
  description = "Service image as repo:tag"
  type        = string
  default     = "madg-construction-observations-service:latest"
}

variable "sync_job_image" {
  description = "Sync job image as repo:tag. May reuse the service image with a job entrypoint."
  type        = string
  default     = "madg-construction-observations-service:latest"
}

variable "sync_job_command" {
  description = "Entrypoint for the scheduled sync job. TODO: confirm with the application team."
  type        = list(string)
  default     = ["node", "jobs/sync.js"]
}

variable "sync_cron_expression" {
  description = "Sync schedule. Current behaviour is every 15 minutes, but must execute only once per cycle."
  type        = string
  default     = "*/15 * * * *"
}

variable "frontend_replicas" {
  description = "Frontend min/max replicas (on-prem: 3 pods at 0.5 vCPU / 512MB)"
  type        = object({ min = number, max = number })
  default     = { min = 1, max = 3 }
}

variable "service_replicas" {
  description = "Service min/max replicas (on-prem: 3 pods at 2 vCPU / 4GB peak)"
  type        = object({ min = number, max = number })
  default     = { min = 1, max = 3 }
}

##############################
# Integrations
##############################
variable "ppm_soap_url" {
  description = "On-prem PPM SOAP endpoint reached over ExpressRoute"
  type        = string
  default     = "https://ppm.bchydro.bc.ca/DailyReportPublished"
}

variable "alert_emails" {
  description = "Email receivers for the AS3 - Mobile App support action group"
  type        = map(string)
  default     = {}
}

##############################
# Pipeline
##############################
variable "deployer_ip_allowlist" {
  description = "Public IPs allowed through the Key Vault firewall when the vault is first created, so a GitHub-hosted runner can seed secrets. The pipeline opens/closes the firewall itself on later runs, so changes are ignored after creation."
  type        = list(string)
  default     = []
}

variable "use_placeholder_images" {
  description = "Run public Microsoft quickstart images (port 80, no probes) instead of the ACR images. Keep true until the app images are pushed to ACR."
  type        = bool
  default     = true
}
