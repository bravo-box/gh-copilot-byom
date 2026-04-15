locals {
  # Storage account names: 3-24 chars, lowercase letters and numbers only
  storage_account_name = "${substr(replace(var.project_name, "-", ""), 0, 21)}sa"

  # Windows computer names are limited to 15 characters
  vm_computer_name = substr(replace(var.project_name, "-", ""), 0, 15)
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${var.project_name}"
  location = var.location
}

# ---------------------------------------------------------------------------
# Virtual Network & Subnets
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_address_space]
}

resource "azurerm_subnet" "virtual_machines" {
  name                 = "virtual-machines"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_virtual_machines_prefix]

  service_endpoints = [
    "Microsoft.CognitiveServices",
    "Microsoft.Storage",
  ]
}

resource "azurerm_subnet" "aoai" {
  name                 = "aoai"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_aoai_prefix]

  service_endpoints = [
    "Microsoft.CognitiveServices",
    "Microsoft.Storage",
  ]
}

# Must be named exactly "AzureBastionSubnet" – Azure Bastion requirement
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_bastion_prefix]
}

# ---------------------------------------------------------------------------
# Azure Bastion
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "bastion" {
  name                = "${var.project_name}-bastion-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "${var.project_name}-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# ---------------------------------------------------------------------------
# Windows Data Science VM
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "vm" {
  name                = "${var.project_name}-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.virtual_machines.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "${var.project_name}-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  computer_name       = local.vm_computer_name

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "microsoft-dsvm"
    offer     = "dsvm-win-2022"
    sku       = "winserver-2022"
    version   = "latest"
  }
}

# ---------------------------------------------------------------------------
# Azure OpenAI (Cognitive Services)
# ---------------------------------------------------------------------------
resource "azurerm_cognitive_account" "aoai" {
  name                          = "${var.project_name}-aoai"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  kind                          = "OpenAI"
  sku_name                      = var.aoai_sku
  custom_subdomain_name         = "${var.project_name}-aoai"
  public_network_access_enabled = true

  network_acls {
    default_action = "Deny"

    virtual_network_rules {
      subnet_id = azurerm_subnet.virtual_machines.id
    }

    virtual_network_rules {
      subnet_id = azurerm_subnet.aoai.id
    }
  }
}

resource "azurerm_cognitive_deployment" "gpt51" {
  name                 = var.gpt51_deployment_name
  cognitive_account_id = azurerm_cognitive_account.aoai.id

  model {
    format  = "OpenAI"
    name    = "gpt-5.1"
    version = "2025-11-13"
  }

  scale {
    type     = "DataZoneStandard"
    capacity = var.gpt51_capacity
  }
}

# ---------------------------------------------------------------------------
# Current client identity – used for RBAC on the storage account
# ---------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Storage Account (shared-key / SAS auth disabled)
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "storage" {
  name                            = local.storage_account_name
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication_type
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]

    virtual_network_subnet_ids = [
      azurerm_subnet.virtual_machines.id,
      azurerm_subnet.aoai.id,
    ]
  }
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
