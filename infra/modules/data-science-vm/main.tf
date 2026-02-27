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
# Windows Server Data Science Virtual Machine
# ---------------------------------------------------------------------------
# Note: Before applying, accept the marketplace image terms once per subscription:
#   az vm image terms accept --publisher microsoft-dsvm --offer windows-2022 --plan 2022
# ---------------------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "dsvm" {
  name                = "${var.prefix}-dsvm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.dsvm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  # Windows Server 2022 Data Science VM marketplace image
  source_image_reference {
    publisher = "microsoft-dsvm"
    offer     = "dsvm-win-2022"
    sku       = "winserver-2022"
    version   = "latest"
  }

  # plan {
  #   name      = "2022"
  #   publisher = "microsoft-dsvm"
  #   product   = "dsvm-win-2022"
  # }

  tags = var.tags
}
