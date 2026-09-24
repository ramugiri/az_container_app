#!/usr/bin/env bash
# One-time setup so the mcm-infra GitHub Actions workflow can deploy to Azure.
# Run from Git Bash / Azure Cloud Shell with az CLI logged in as a user who can
# create app registrations and assign roles (Owner on the subscription).
#
#   ./scripts/bootstrap-azure.sh <github-owner/repo> <subscription-id> [environments]
#
#   ./scripts/bootstrap-azure.sh myorg/az-mcm-app-infra 1111-... "dev uat"   # non-prod sub
#   ./scripts/bootstrap-azure.sh myorg/az-mcm-app-infra 2222-... "prd"       # prod sub
#
# Creates (idempotently):
#   - Terraform state storage account + container
#   - Entra app registration + service principal with GitHub OIDC federated
#     credentials, one per GitHub environment
#   - Contributor + User Access Administrator on the subscription (Terraform creates
#     role assignments), Storage Blob Data Contributor on the state account
# and prints the GitHub environment secrets/variables to set.
set -euo pipefail
export MSYS_NO_PATHCONV=1 # stop Git Bash rewriting /subscriptions/... scopes

REPO="${1:?usage: $0 <github-owner/repo> <subscription-id> [environments]}"
SUBSCRIPTION_ID="${2:?usage: $0 <github-owner/repo> <subscription-id> [environments]}"
ENVIRONMENTS="${3:-dev uat prd}"
LOCATION="${LOCATION:-canadacentral}"
STATE_RG="${STATE_RG:-rg-mcm-tfstate}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"
APP_NAME="${APP_NAME:-gh-az-mcm-app-infra}"

az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)
SCOPE="/subscriptions/$SUBSCRIPTION_ID"

echo "==> Registering resource providers"
for ns in Microsoft.App Microsoft.ContainerRegistry Microsoft.DBforPostgreSQL Microsoft.KeyVault \
          Microsoft.Storage Microsoft.Network Microsoft.OperationalInsights Microsoft.Insights \
          Microsoft.ManagedIdentity; do
  az provider register --namespace "$ns" -o none
done

echo "==> Terraform state storage"
az group create -n "$STATE_RG" -l "$LOCATION" -o none
# Storage account names are global: derive a stable, subscription-specific suffix.
STATE_SA="${STATE_SA:-stmcmtfstate$(echo -n "$SUBSCRIPTION_ID" | md5sum | cut -c1-8)}"
if ! az storage account show -n "$STATE_SA" -g "$STATE_RG" -o none 2>/dev/null; then
  az storage account create -n "$STATE_SA" -g "$STATE_RG" -l "$LOCATION" \
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
    --allow-blob-public-access false -o none
fi
az storage account blob-service-properties update -n "$STATE_SA" -g "$STATE_RG" \
  --enable-versioning true -o none
az storage container create -n "$STATE_CONTAINER" --account-name "$STATE_SA" \
  --auth-mode login -o none 2>/dev/null || \
az storage container create -n "$STATE_CONTAINER" --account-name "$STATE_SA" -o none
STATE_SA_ID=$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --query id -o tsv)

echo "==> App registration + service principal"
CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$CLIENT_ID" ]; then
  CLIENT_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
fi
if ! az ad sp show --id "$CLIENT_ID" -o none 2>/dev/null; then
  az ad sp create --id "$CLIENT_ID" -o none
fi
SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv)

echo "==> Federated credentials"
for env in $ENVIRONMENTS; do
  name="github-${env}"
  if ! az ad app federated-credential show --id "$CLIENT_ID" --federated-credential-id "$name" -o none 2>/dev/null; then
    az ad app federated-credential create --id "$CLIENT_ID" --parameters "{
      \"name\": \"$name\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"repo:${REPO}:environment:${env}\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" -o none
  fi
done

echo "==> Role assignments (may take a minute to propagate)"
assign() {
  az role assignment create --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal \
    --role "$1" --scope "$2" -o none 2>/dev/null || true
}
assign "Contributor" "$SCOPE"
assign "User Access Administrator" "$SCOPE"
assign "Storage Blob Data Contributor" "$STATE_SA_ID"

cat <<EOF

Done. In GitHub: Settings -> Environments -> create each of: $ENVIRONMENTS
and add to EACH environment:

  Secrets
    AZURE_CLIENT_ID        = $CLIENT_ID
    AZURE_TENANT_ID        = $TENANT_ID
    AZURE_SUBSCRIPTION_ID  = $SUBSCRIPTION_ID

  Variables
    TFSTATE_RESOURCE_GROUP  = $STATE_RG
    TFSTATE_STORAGE_ACCOUNT = $STATE_SA
    TFSTATE_CONTAINER       = $STATE_CONTAINER
EOF
