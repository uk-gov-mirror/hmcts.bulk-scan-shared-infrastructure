provider "azurerm" {
  alias           = "cft-mgmt"
  subscription_id = "ed302caf-ec27-4c64-a05e-85731c3ce90e"
  features {}
}

# data "azurerm_key_vault" "bulk_scan_key_vault" {
#   name                = "bulk-scan-${var.env}"
#   resource_group_name = "bulk-scan-${var.env}"
# }

data "azurerm_public_ip" "proxy_out_public_ip" {
  provider            = "azurerm.cft-mgmt"
  name                = "reformMgmtProxyOutPublicIP"
  resource_group_name = "reformMgmtDmzRG"
}

data "azurerm_key_vault_secret" "aks00_public_ip_prefix" {
  name         = "nsg-aks00-pip"
  key_vault_id = "${module.vault.key_vault_id}"
}

data "azurerm_key_vault_secret" "aks01_public_ip_prefix" {
  name         = "nsg-aks01-pip"
  key_vault_id = "${module.vault.key_vault_id}"
}

resource "azurerm_network_security_group" "bulkscannsg" {
  name                = "bulk-scan-nsg-${var.env}"
  resource_group_name = "core-infra-${var.env}"
  location            = "${var.location}"

  security_rule {
    name                       = "allow-inbound-https-proxyout"
    direction                  = "Inbound"
    access                     = "Allow"
    priority                   = 100
    source_address_prefixes    = ["${data.azurerm_public_ip.proxy_out_public_ip.ip_address}"]
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
    protocol                   = "TCP"
  }

  security_rule {
    name                       = "allow-inbound-https-internal"
    direction                  = "Inbound"
    access                     = "Allow"
    priority                   = 110
    source_address_prefixes      = ["${data.azurerm_key_vault_secret.aks00_public_ip_prefix.value}", "${data.azurerm_key_vault_secret.aks01_public_ip_prefix.value}"]
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
    protocol                   = "TCP"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = "${data.azurerm_subnet.subnet_a.id}"
  network_security_group_id = "${azurerm_network_security_group.bulkscannsg.id}"
}