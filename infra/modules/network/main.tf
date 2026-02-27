locals {
  # Determine whether to create a new VNet or reuse an existing one.
  create_vnet = var.vnet_id == ""

  # When reusing an existing VNet, parse its name and resource group from the ID.
  # Azure VNet IDs follow the pattern:
  #   /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<name>
  existing_vnet_name = local.create_vnet ? "" : split("/", var.vnet_id)[8]
  existing_vnet_rg   = local.create_vnet ? "" : split("/", var.vnet_id)[4]

  vnet_name = local.create_vnet ? azurerm_virtual_network.main[0].name : local.existing_vnet_name
  vnet_rg   = local.create_vnet ? var.resource_group_name : local.existing_vnet_rg
  vnet_id   = local.create_vnet ? azurerm_virtual_network.main[0].id : var.vnet_id
}

# ---------------------------------------------------------------------------
# Virtual Network (created only when vnet_id is not provided)
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  count = local.create_vnet ? 1 : 0

  name                = "${var.prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

# Development VMs subnet
resource "azurerm_subnet" "dev_vms" {
  name                 = "dev-vms"
  resource_group_name  = local.vnet_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.dev_vms_subnet_cidr]
}

# AI Foundry subnet
resource "azurerm_subnet" "ai_foundry" {
  name                 = "ai-foundry"
  resource_group_name  = local.vnet_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.ai_foundry_subnet_cidr]
}

# Azure Bastion requires this exact subnet name
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = local.vnet_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.bastion_subnet_cidr]
}
# ---------------------------------------------------------------------------
# Network Security Groups (NSGs) – to block outbound internet traffic
# ---------------------------------------------------------------------------

# NSG for dev-vms subnet
resource "azurerm_network_security_group" "dev_vms" {
  name                = "${var.prefix}-dev-vms-nsg"
  location            = var.location
  resource_group_name = local.vnet_rg
  tags                = var.tags
}

# NSG for ai-foundry subnet
resource "azurerm_network_security_group" "ai_foundry" {
  name                = "${var.prefix}-ai-foundry-nsg"
  location            = var.location
  resource_group_name = local.vnet_rg
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# NSG Rules – Block outbound internet traffic (when enabled)
# ---------------------------------------------------------------------------

# Allow inbound traffic from within the VNet
resource "azurerm_network_security_rule" "allow_vnet_inbound_dev_vms" {
  count = var.block_internet_outbound ? 1 : 0

  name                        = "AllowVNetInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = local.vnet_rg
  network_security_group_name = azurerm_network_security_group.dev_vms.name
}

resource "azurerm_network_security_rule" "allow_vnet_inbound_ai_foundry" {
  count = var.block_internet_outbound ? 1 : 0

  name                        = "AllowVNetInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = local.vnet_rg
  network_security_group_name = azurerm_network_security_group.ai_foundry.name
}

# Allow outbound traffic within the VNet
resource "azurerm_network_security_rule" "allow_vnet_outbound_dev_vms" {
  count = var.block_internet_outbound ? 1 : 0

  name                        = "AllowVNetOutbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = local.vnet_rg
  network_security_group_name = azurerm_network_security_group.dev_vms.name
}

resource "azurerm_network_security_rule" "allow_vnet_outbound_ai_foundry" {
  count = var.block_internet_outbound ? 1 : 0

  name                        = "AllowVNetOutbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = local.vnet_rg
  network_security_group_name = azurerm_network_security_group.ai_foundry.name
}

# Deny all outbound traffic to the internet (0.0.0.0/0)
resource "azurerm_network_security_rule" "deny_internet_outbound_dev_vms" {
  count = var.block_internet_outbound ? 1 : 0

  name                        = "DenyInternetOutbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = local.vnet_rg
  network_security_group_name = azurerm_network_security_group.dev_vms.name
}

resource "azurerm_network_security_rule" "deny_internet_outbound_ai_foundry" {
  count = var.block_internet_outbound ? 1 : 0

  name                        = "DenyInternetOutbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = local.vnet_rg
  network_security_group_name = azurerm_network_security_group.ai_foundry.name
}

# ---------------------------------------------------------------------------
# Associate NSGs with Subnets
# ---------------------------------------------------------------------------

resource "azurerm_subnet_network_security_group_association" "dev_vms" {
  subnet_id                 = azurerm_subnet.dev_vms.id
  network_security_group_id = azurerm_network_security_group.dev_vms.id
}

resource "azurerm_subnet_network_security_group_association" "ai_foundry" {
  subnet_id                 = azurerm_subnet.ai_foundry.id
  network_security_group_id = azurerm_network_security_group.ai_foundry.id
}
