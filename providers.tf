terraform {
  required_version = ">= 1.7.0"

  # State lives in Azure Storage. Partial config - the pipeline supplies
  # storage_account_name, container_name, resource_group_name and key per environment.
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    # The storage account is private-only; manage it through ARM so the
    # pipeline runner never needs data-plane access to it.
    storage {
      data_plane_available = false
    }
  }
  use_oidc        = true
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}
