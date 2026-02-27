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
