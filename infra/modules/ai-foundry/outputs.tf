output "openai_endpoint" {
  description = "HTTPS endpoint of the Azure OpenAI service."
  value       = azurerm_cognitive_account.openai.endpoint
}

output "openai_id" {
  description = "Resource ID of the Azure OpenAI Cognitive Services account."
  value       = azurerm_cognitive_account.openai.id
}

# output "gpt4o_deployment_name" {
#   description = "Name of the GPT-4o model deployment."
#   value       = azurerm_cognitive_deployment.gpt4o.name
# }

output "ai_foundry_id" {
  description = "Resource ID of the AI Foundry Hub."
  value       = azurerm_ai_foundry.main.id
}

output "ai_foundry_name" {
  description = "Name of the AI Foundry Hub."
  value       = azurerm_ai_foundry.main.name
}

output "storage_account_id" {
  description = "Resource ID of the AI Foundry storage account."
  value       = azurerm_storage_account.ai_foundry.id
}

output "key_vault_id" {
  description = "Resource ID of the AI Foundry Key Vault."
  value       = azurerm_key_vault.ai_foundry.id
}
