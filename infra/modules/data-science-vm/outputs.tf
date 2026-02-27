output "vm_id" {
  description = "Resource ID of the Data Science Virtual Machine."
  value       = azurerm_windows_virtual_machine.dsvm.id
}

output "vm_name" {
  description = "Name of the Data Science Virtual Machine."
  value       = azurerm_windows_virtual_machine.dsvm.name
}

output "private_ip_address" {
  description = "Private IP address of the Data Science VM (reachable via Azure Bastion)."
  value       = azurerm_network_interface.dsvm.private_ip_address
}

output "nic_id" {
  description = "Resource ID of the VM network interface card."
  value       = azurerm_network_interface.dsvm.id
}
