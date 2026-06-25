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
  value       = var.deploy_vm ? azurerm_public_ip.bastion[0].ip_address : null
}

output "vm_id" {
  description = "Resource ID of the Windows Data Science VM."
  value       = var.deploy_vm ? azurerm_windows_virtual_machine.vm[0].id : null
}

output "vm_private_ip" {
  description = "Private IP address of the Windows Data Science VM."
  value       = var.deploy_vm ? azurerm_network_interface.vm[0].private_ip_address : null
}

output "aoai_id" {
  description = "Resource ID of the Azure OpenAI Cognitive Services account."
  value       = azurerm_cognitive_account.aoai.id
}

output "aoai_endpoint" {
  description = "Endpoint URL for the Azure OpenAI instance."
  value       = azurerm_cognitive_account.aoai.endpoint
}

output "aoai_primary_key" {
  description = "Primary access key for the Azure OpenAI instance."
  value       = azurerm_cognitive_account.aoai.primary_access_key
  sensitive   = true
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

output "aoai_responses_url" {
  description = "Full Azure OpenAI responses API URL for use in chatLanguageModels.json (Packer BYOM configuration)."
  value       = "${azurerm_cognitive_account.aoai.endpoint}openai/responses?api-version=2025-04-01-preview"
}
