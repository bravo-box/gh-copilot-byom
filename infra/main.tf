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
# Network Security Group – VM subnet (deny all outbound, allow Bastion in)
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "vm" {
  name                = "${var.project_name}-vm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow inbound RDP from Bastion subnet
  security_rule {
    name                       = "AllowBastionRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.subnet_bastion_prefix
    destination_address_prefix = "*"
  }

  # Allow inbound SSH from Bastion subnet
  security_rule {
    name                       = "AllowBastionSSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.subnet_bastion_prefix
    destination_address_prefix = "*"
  }

  # Deny all outbound traffic
  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.virtual_machines.id
  network_security_group_id = azurerm_network_security_group.vm.id
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

# ---------------------------------------------------------------------------
# Private DNS Zones (Azure Government endpoints)
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "cognitiveservices" {
  name                = "privatelink.cognitiveservices.azure.us"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.usgovcloudapi.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "cognitiveservices" {
  name                  = "${var.project_name}-aoai-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.cognitiveservices.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${var.project_name}-blob-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# ---------------------------------------------------------------------------
# Private Endpoint – Azure OpenAI
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "aoai" {
  name                = "${var.project_name}-aoai-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.virtual_machines.id

  private_service_connection {
    name                           = "${var.project_name}-aoai-psc"
    private_connection_resource_id = azurerm_cognitive_account.aoai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "aoai-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.cognitiveservices.id]
  }
}

# ---------------------------------------------------------------------------
# Private Endpoint – Blob Storage
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "blob" {
  name                = "${var.project_name}-blob-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.virtual_machines.id

  private_service_connection {
    name                           = "${var.project_name}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}
