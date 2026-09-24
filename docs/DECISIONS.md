# Architecture decisions - MCM

| # | Decision | Rationale | Status |
|---|---|---|---|
| 1 | Azure Container Apps over AKS / App Service | Already containerized; independent frontend/service deploys map 1:1; ACA Job gives single-execution scheduling without leader election. A dedicated AKS cluster is disproportionate for a Bronze app at ~6.5 vCPU peak. | **Pending platform team ratification** |
| 2 | Scheduled ACA Job for the 15-minute sync | Q2: the job must run once, not on all replicas. `parallelism = 1` guarantees it. | Confirmed with app team intent |
| 3 | Retain SAP Mobile Services / IAS / XSUAA auth | Confirmed by the app team (Sep 1). No EasyAuth, no auth refactor. Azure-side dependency is outbound reachability to SAP BTP only. | Confirmed |
| 4 | PostgreSQL Flexible Server, VNet-injected | DB-10 target is PaaS. Delegated subnet rather than private endpoint. Flip to PE if the platform standard requires it - one-file change, but it means a new server. | **Open (review point 7: SKU / HA TBD)** |
| 5 | Azure Files SMB, Standard LRS, large file share | Not IOPS sensitive; preserves SMB semantics; 930GB into a 2TB quota. | Confirmed |
| 6 | PPM stays SOAP + Basic Auth over ExpressRoute | Q5: "Yes, unless PPM side provides another way". Credential in Key Vault, retrieved by the app's managed identity. Managed identity does **not** authenticate to PPM directly. | Confirmed |
| 7 | No NAT Gateway | Confirmed not required for MCM. Outbound traffic leaves via the platform hub path; firewall rules are scoped by the ACA subnet CIDR rather than a workload-owned egress IP. If a downstream endpoint later requires a fixed source IP, that is a platform/hub concern first (see note in README). | **Closed - not required** |
| 8 | Private DNS zones created in the spoke | Toggle `create_private_dns_zones = false` and pass zone IDs if the platform team owns them centrally in the hub. | **Open - platform team** |
| 9 | One user-assigned managed identity for apps and job | A container app referencing Key Vault secrets needs vault access at creation time; a system-assigned identity does not exist until the app is created, so the first apply fails. A UAMI created and granted up front breaks the cycle. | Confirmed |
| 10 | Env vars + Key Vault references, no App Configuration | Config surface is small and the app reads env vars today; App Configuration would need an SDK change in both repos. Add it if the landing-zone standard mandates it. | **Open - platform team** |
