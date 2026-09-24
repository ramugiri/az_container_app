# /23 minimum, delegated to Microsoft.App. Immutable once the ACA environment exists.
resource "azurerm_subnet" "aca" {
  name                 = local.names.snet_aca
  resource_group_name  = azurerm_resource_group.mcm.name
  virtual_network_name = azurerm_virtual_network.mcm.name
  address_prefixes     = [var.subnet_prefixes.aca]

  delegation {
    name = "aca-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "pep" {
  name                              = local.names.snet_pep
  resource_group_name               = azurerm_resource_group.mcm.name
  virtual_network_name              = azurerm_virtual_network.mcm.name
  address_prefixes                  = [var.subnet_prefixes.pep]
  private_endpoint_network_policies = "Enabled"
}

# VNet-injected PostgreSQL. Swap to a private endpoint if the platform standard requires it.
resource "azurerm_subnet" "psql" {
  name                 = local.names.snet_psql
  resource_group_name  = azurerm_resource_group.mcm.name
  virtual_network_name = azurerm_virtual_network.mcm.name
  address_prefixes     = [var.subnet_prefixes.psql]

  delegation {
    name = "psql-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
