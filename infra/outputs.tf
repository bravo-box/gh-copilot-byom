output "resource_group_name" {
  description = "Name of the deployed resource group."
  value       = azurerm_resource_group.rg.name
}

output "resource_group_id" {
  description = "Resource ID of the deployed resource group."
  value       = azurerm_resource_group.rg.id
}

output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.vnet.name
}

output "subnet_virtual_machines_id" {
  description = "Resource ID of the virtual-machines subnet."
  value       = azurerm_subnet.virtual_machines.id
}

output "subnet_aoai_id" {
  description = "Resource ID of the aoai subnet."
  value       = azurerm_subnet.aoai.id
}

output "subnet_bastion_id" {
  description = "Resource ID of the AzureBastionSubnet."
  value       = azurerm_subnet.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP address of the Azure Bastion host."
  value       = azurerm_public_ip.bastion.ip_address
}

output "vm_id" {
  description = "Resource ID of the Windows Data Science VM."
  value       = azurerm_windows_virtual_machine.vm.id
}

output "vm_private_ip" {
  description = "Private IP address of the Windows Data Science VM."
  value       = azurerm_network_interface.vm.private_ip_address
}

output "aoai_id" {
  description = "Resource ID of the Azure OpenAI Cognitive Services account."
  value       = azurerm_cognitive_account.aoai.id
}

output "aoai_endpoint" {
  description = "Endpoint URL for the Azure OpenAI instance."
  value       = azurerm_cognitive_account.aoai.endpoint
}

output "aoai_deployment_name" {
  description = "Name of the GPT-5.1 model deployment."
  value       = azurerm_cognitive_deployment.gpt51.name
}

output "storage_account_name" {
  description = "Name of the storage account."
  value       = azurerm_storage_account.storage.name
}

output "storage_account_id" {
  description = "Resource ID of the storage account."
  value       = azurerm_storage_account.storage.id
}

output "storage_primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account."
  value       = azurerm_storage_account.storage.primary_blob_endpoint
}
