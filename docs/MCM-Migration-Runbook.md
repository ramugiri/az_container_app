# MCM (Mobile Construction Management) — Azure Migration Runbook

**Application:** MADG Construction Observations (web + iOS)
**Wave:** 1 | **Approach:** parallel build in Azure, cutover planned separately
**App repos:** `bchydro/madg-construction-observations` (frontend), `bchydro/madg-construction-observations-service` (service)
**Infra repo:** `az-mcm-app-infra`
**Support:** AS3 — Mobile App support | **SLA:** Bronze, RTO/RPO business hours, no HA/DR

---

## 1. Current state (from discovery)

| Item | Detail |
|---|---|
| Compute | Kubernetes: 3 frontend pods (0.5 vCPU / 512MB each) + 3 service pods (2 vCPU / 4GB each, peak). Built/deployed independently. |
| Scheduled job | Node.js sync runs every 15 min **on all 3 pods** (to be single-execution in target — confirmed by Sarbjeet) |
| Database | PostgreSQL, ~25GB, shared server / standalone schema, port 5432, nightly backup 7-day rolling, not IOPS-sensitive (heavy on 3-month data downloads) |
| Files | CISF SMB share `//esri-shelf/ESRICONOBS`, ~930GB used, username/password auth |
| Auth | SAP Mobile Services (iOS + web) → SAP IAS → Entra ID; XSUAA provides OAuth flow. **Retained after migration** (confirmed Sep 1). |
| PPM | PDF reports published to on-prem PPM via SOAP + Basic Auth: `https://ppm.bchydro.bc.ca/DailyReportPublished`. **Same interface post-migration** unless PPM offers an alternative. |
| Network | ExpressRoute hybrid; on-prem DNS with F5 in front — Dev `w3df5`, UAT `w3tf5`, PRD `w3f5` (`...bchydro.bc.ca:8443/mash/dailyreport/`) |
| Servers | Prod: `kdcbchmobapp01` (Linux), `kdcbchmobprddb1`. Non-prod: `kdcbchmobapps01`, `kdcbchmobdevdb1`, `kdcbchmobuatdb1` |
| Data | Internal classification, no PII, no compliance holds |
| Email | App-triggered email + users emailing reports via local mail client — confirm SMTP relay reachability from Azure |

## 2. Target state

Azure Container Apps (internal environment, VNet-integrated) with frontend app, service app, and a **scheduled ACA Job** (`*/15 * * * *`, parallelism 1) replacing the multi-pod sync. PostgreSQL Flexible Server (VNet-delegated). Azure Files SMB share `esriconobs` (2TB quota). Key Vault for PPM creds and connection strings. App Insights + Log Analytics (30-day retention) with action group → AS3. Ingress via platform App Gateway; on-prem reachability (PPM, SMTP) via hub ExpressRoute. Auth flow unchanged (SAP Mobile Services / IAS / XSUAA).

---

## 3. Phase 0 — Prerequisites and approvals (long-lead, start now)

- [ ] **Platform team approval** of Container Apps as the compute pattern (alternative: App Service for Containers — network layout identical). Owner: Ram → platform team.
- [ ] CIDR allocation for the MCM spoke VNet (prod + non-prod) from the network team; update `*.tfvars`.
- [ ] Hub peering + `use_remote_gateways` sign-off; hub-side peering applied by platform team.
- [ ] **Firewall rules table (NET-03)** submitted to network team, scoped by the ACA subnet CIDR as source. Confirm with them what the outbound path and SNAT address will be (hub firewall vs. platform default) so any IP-based allow-listing on the PPM/SAP side is registered against the right address. Required flows:
  - ACA subnet → on-prem PPM `ppm.bchydro.bc.ca:443` (SOAP)
  - ACA subnet → SMTP relay (host/port TBD — confirm with infra)
  - ACA subnet → SAP BTP / Mobile Services + XSUAA endpoints (HTTPS 443) — get exact hostnames from SAP admin
  - Migration jump host → PostgreSQL Flexible Server `:5432`, → storage account `:445`
  - On-prem robocopy/azcopy source → storage account private endpoint `:445` / `:443`
- [ ] Private DNS zone ownership decision: spoke-created (as coded) vs platform-managed hub zones.
- [ ] App Gateway listener + backend pool request to platform team (backend = ACA environment static IP / frontend FQDN; health probe path from app team).
- [ ] DNS/F5 cutover plan agreed with network team for `w3f5/w3tf5/w3df5...:8443/mash/dailyreport/` — decide whether F5 remains in path (proxying to App Gateway) or DNS moves to App Gateway directly. Hardcoded URL check in app config (NET-02).
- [ ] Confirm sync job entrypoint (`command` in `ContainerAppJob.tf`) and that `SYNC_JOB_ENABLED=false` (or equivalent) disables the in-pod interval timer — with Sarbjeet's team. Ask them to also make the k8s side single-pod as they planned, so behaviour matches during parallel run.
- [ ] Licensing (LIC-01 "Custom"): confirm no COTS/licensing blocker with procurement; Azure Hybrid Benefit N/A for ACA.
- [ ] GitHub environments (`dev`/`uat`/`prd`) with `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` secrets and `TFSTATE_*` variables (see README; `scripts/bootstrap-azure.sh` prints them) — watch env-vs-repo scoping (same issue hit on CNS).
- [ ] Entra app registrations / federated credentials for GitHub OIDC per environment.

## 4. Phase 1 — Infrastructure deployment (per environment: dev → uat → prd)

1. PR to `az-mcm-app-infra` → plan-only run; review the plan in the Actions log.
2. `workflow_dispatch` with `apply=true` (gated) → deploy.
3. Record outputs: `aca_subnet_prefix` (→ firewall table source scope), `aca_environment_static_ip` + `frontend_fqdn` (→ App Gateway backend), `psql_fqdn`, `key_vault_uri`.
4. Seed Key Vault secrets (manual/pipeline, never in tfvars):
   - `ppm-basic-auth` — PPM service account creds (existing service account for now; IAM-03 conversion to managed identity is a PPM-side item)
   - `psql-connection-string` — `postgresql://mcmadmin:<from kv psql-admin-password>@<psql_fqdn>:5432/mcm?sslmode=require`
5. Verify from a VNet jump host: `nslookup` for KV/storage/ACR/psql resolve to private IPs; `psql` connects on 5432; SMB mount of `esriconobs` works.

## 5. Phase 2 — Data migration

### 5.1 File share (LONGEST LEAD — start immediately after Phase 1 in prod)
1. Initial bulk copy of ~930GB over ExpressRoute (estimate: at 500 Mbps effective ≈ 4–5 hours per full pass; plan a weekend window and throttle if needed):
   `azcopy copy "\\\\esri-shelf\\ESRICONOBS" "https://<storage>.file.core.windows.net/esriconobs<SAS>" --recursive --preserve-smb-info`
   (or `robocopy /MIR /Z /MT:16 /XJ /R:2 /W:5 /LOG:...` to a mounted Azure Files path if SMB metadata/ACL fidelity matters).
2. Incremental delta syncs nightly until cutover (`azcopy sync` / `robocopy /MIR`).
3. Final delta during the cutover freeze; capture file count + total size on both sides and reconcile.

### 5.2 Database (~25GB, import/export per DB-09)
1. Freeze schema changes; announce migration window.
2. Dump from `kdcbchmobprddb1`:
   `pg_dump -h kdcbchmobprddb1 -U <user> -Fc -Z 6 -f mcm_prd.dump <dbname>`
3. Restore to Flexible Server (from jump host in/peered to the VNet):
   `pg_restore -h <psql_fqdn> -U mcmadmin -d mcm --no-owner --no-privileges -j 4 mcm_prd.dump`
4. Reconcile: row counts per table, checksums on key tables, sequence values (`setval`), extension list.
5. Rehearse full dump/restore in dev and UAT first and time it (sets the prod window).

## 6. Phase 3 — Application build and deploy

1. Add GitHub Actions build workflows to both app repos: build image → push to ACR (OIDC + `az acr login`) → tag per environment. (Mirror the `multi-env-deploy.yml` / reusable-workflow pattern from ECSI.)
2. Deploy dev revision; confirm:
   - App Insights telemetry flowing (`APPLICATIONINSIGHTS_CONNECTION_STRING`)
   - Azure Files mount visible at `/mnt/conobs`, read/write OK
   - DB connectivity with `sslmode=require`
3. Trigger the sync job manually (`az containerapp job start`) — verify exactly one execution, correct results, then let the cron take over. Confirm the in-app interval timer is disabled.
4. Verify PPM SOAP publish from Azure (this validates the firewall rule + ER path) — publish a test report, confirm in PPM.
5. Verify email trigger path (SMTP relay reachable from ACA subnet).
6. Auth smoke test: iOS app + web login through SAP Mobile Services / IAS → Entra ID → XSUAA token issued → API accepts token. Token stored via SAP plugin storage on iOS as today. **No redirect URI changes should be needed** since hostnames only change at cutover — if the F5 hostname changes, update SAP Mobile Services destination/redirect config accordingly.

## 7. Phase 4 — Validation (UAT)

- [ ] Functional regression by business users on UAT (`w3tf5` path pointed at Azure, or temporary Azure hostname)
- [ ] 3-month data download scenario (the known heavy DB pattern) — compare latency vs on-prem
- [ ] Sync job: 24h observation, exactly 96 executions, no overlaps
- [ ] PDF → PPM publish end-to-end
- [ ] Load test to current peak (3 × 2 vCPU service equivalent); confirm ACA scale 1→3
- [ ] Alerts fire to AS3 (test action group)
- [ ] Log retention/queries in Log Analytics meet the 30-day + audit needs (replaces NFS/Victoria logs)

## 8. Phase 5 — Production cutover

**Window:** aligned to Bronze/business-hours RTO — recommend Friday evening.

1. T-7d: final firewall rules confirmed; App Gateway prod listener live (tested via hosts-file override).
2. T-1d: incremental file sync; comms to users; change record approved.
3. T-0:
   - Freeze writes on-prem (scale k8s to 0 or maintenance page)
   - Final DB dump/restore + reconciliation (timed in rehearsal)
   - Final file delta sync + reconciliation
   - Enable ACA sync job schedule; confirm k8s cron disabled
   - DNS/F5 switch: point `w3f5.bchydro.bc.ca` path at App Gateway
   - Smoke test: login (web + iOS), create observation, attach file, download 3-month data, publish PDF to PPM, trigger email
4. Hypercare: 5 business days, AS3 + app team on standby; monitor App Insights failures/latency dashboards.

## 9. Rollback

- Trigger criteria: auth failures, PPM publish failures, or data integrity issues not resolvable within the agreed window.
- Action: revert DNS/F5 to on-prem k8s (kept warm, scaled back up), re-enable k8s sync, unfreeze on-prem writes. Files: on-prem share remains source of truth until T+5d — any files written to Azure Files during the failed window must be synced back before reopening on-prem.
- DB: on-prem DB untouched during migration (dump-based), so rollback is pointer-only unless writes occurred in Azure — if so, reverse dump/restore of changed tables (identify via updated_at) before reopening.
- Decommission on-prem (`kdcbchmobapp01`, DB schema on `kdcbchmobprddb1`, CISF share) only after T+30d stable.

## 10. Open items / risks

| # | Item | Owner | Risk |
|---|---|---|---|
| 1 | Platform approval: ACA vs App Service | Ram / platform team | Rework of compute Terraform if App Service mandated |
| 2 | SAP BTP endpoint allowlist for firewall table | SAP admin | Auth breaks from Azure egress if missed |
| 3 | Sync job entrypoint + timer kill-switch in service code | App team (Sarbjeet) | Duplicate sync executions |
| 4 | SMTP relay details from Azure | Infra | Email feature regression |
| 5 | PPM service account → managed identity (IAM-03) | PPM team | Deferred — basic auth via KV acceptable interim |
| 6 | 930GB copy window over shared ExpressRoute | Network team | Bandwidth contention; schedule off-hours |
| 7 | Private DNS zone ownership (spoke vs hub) | Platform team | Terraform refactor to data sources |
| 8 | F5-in-path vs direct App Gateway decision | Network team | Cutover mechanics change |
