resource "azurerm_network_security_group" "aca" {
  name                = local.names.nsg_aca
  location            = azurerm_resource_group.mcm.location
  resource_group_name = azurerm_resource_group.mcm.name
  tags                = local.common_tags

  # Ingress arrives from the platform Application Gateway only.
  security_rule {
    name                       = "allow-appgw-inbound-https"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80"]
    source_address_prefix      = var.appgw_subnet_prefix == null ? "VirtualNetwork" : var.appgw_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-psql-outbound"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = var.subnet_prefixes.psql
  }

  # Azure Files over SMB
  security_rule {
    name                       = "allow-smb-outbound-pep"
    priority                   = 220
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = "*"
    destination_address_prefix = var.subnet_prefixes.pep
  }
}

resource "azurerm_network_security_group" "pep" {
  name                = local.names.nsg_pep
  location            = azurerm_resource_group.mcm.location
  resource_group_name = azurerm_resource_group.mcm.name
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "aca" {
  subnet_id                 = azurerm_subnet.aca.id
  network_security_group_id = azurerm_network_security_group.aca.id
}

resource "azurerm_subnet_network_security_group_association" "pep" {
  subnet_id                 = azurerm_subnet.pep.id
  network_security_group_id = azurerm_network_security_group.pep.id
}
