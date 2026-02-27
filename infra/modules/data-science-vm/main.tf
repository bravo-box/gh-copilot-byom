# Network interface card for the DSVM (private IP only – accessed via Bastion)
resource "azurerm_network_interface" "dsvm" {
  name                = "${var.prefix}-dsvm-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Ubuntu Data Science Virtual Machine
# ---------------------------------------------------------------------------
# Note: Before applying, accept the marketplace image terms once per subscription:
#   az vm image terms accept --publisher microsoft-dsvm --offer ubuntu-2204 --plan 2204
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "dsvm" {
  name                = "${var.prefix}-dsvm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.dsvm.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  # Ubuntu 22.04 Data Science VM marketplace image
  source_image_reference {
    publisher = "microsoft-dsvm"
    offer     = "ubuntu-2204"
    sku       = "2204"
    version   = "latest"
  }

  plan {
    name      = "2204"
    publisher = "microsoft-dsvm"
    product   = "ubuntu-2204"
  }

  tags = var.tags
}
