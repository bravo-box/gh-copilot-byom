# ---------------------------------------------------------------------------
# Network outputs
# ---------------------------------------------------------------------------

output "vnet_id" {
  description = "Resource ID of the virtual network (new or existing)."
  value       = module.network.vnet_id
}

output "dev_vms_subnet_id" {
  description = "Resource ID of the 'dev-vms' subnet."
  value       = module.network.dev_vms_subnet_id
}

output "ai_foundry_subnet_id" {
  description = "Resource ID of the 'ai-foundry' subnet."
  value       = module.network.ai_foundry_subnet_id
}

output "bastion_subnet_id" {
  description = "Resource ID of the 'AzureBastionSubnet'."
  value       = module.network.bastion_subnet_id
}

# ---------------------------------------------------------------------------
# Bastion outputs
# ---------------------------------------------------------------------------

output "bastion_public_ip" {
  description = "Public IP address of the Azure Bastion host (use this to connect to VMs)."
  value       = module.bastion.bastion_public_ip
}

output "bastion_host_id" {
  description = "Resource ID of the Azure Bastion host."
  value       = module.bastion.bastion_host_id
}

# ---------------------------------------------------------------------------
# Data Science VM outputs
# ---------------------------------------------------------------------------

output "dsvm_name" {
  description = "Name of the Data Science Virtual Machine."
  value       = module.data_science_vm.vm_name
}

output "dsvm_private_ip" {
  description = "Private IP address of the Data Science VM (reachable via Bastion)."
  value       = module.data_science_vm.private_ip_address
}

# ---------------------------------------------------------------------------
# AI Foundry / OpenAI outputs
# ---------------------------------------------------------------------------

output "openai_endpoint" {
  description = "HTTPS endpoint of the Azure OpenAI service."
  value       = module.ai_foundry.openai_endpoint
}

output "gpt4o_deployment_name" {
  description = "Name of the GPT-4o model deployment."
  value       = module.ai_foundry.gpt4o_deployment_name
}

output "ai_foundry_id" {
  description = "Resource ID of the AI Foundry Hub."
  value       = module.ai_foundry.ai_foundry_id
}

output "ai_foundry_name" {
  description = "Name of the AI Foundry Hub."
  value       = module.ai_foundry.ai_foundry_name
}
