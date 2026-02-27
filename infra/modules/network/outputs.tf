output "vnet_id" {
  description = "Resource ID of the virtual network (new or existing)."
  value       = local.vnet_id
}

output "dev_vms_subnet_id" {
  description = "Resource ID of the 'dev-vms' subnet."
  value       = azurerm_subnet.dev_vms.id
}

output "ai_foundry_subnet_id" {
  description = "Resource ID of the 'ai-foundry' subnet."
  value       = azurerm_subnet.ai_foundry.id
}

output "bastion_subnet_id" {
  description = "Resource ID of the 'AzureBastionSubnet'."
  value       = azurerm_subnet.bastion.id
}
