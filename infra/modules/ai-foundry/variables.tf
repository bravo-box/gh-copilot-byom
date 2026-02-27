variable "prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the 'ai-foundry' subnet."
  type        = string
}

variable "tenant_id" {
  description = "Azure Active Directory tenant ID."
  type        = string
}

variable "openai_sku" {
  description = "Pricing tier for the Azure OpenAI Cognitive Services account."
  type        = string
  default     = "S0"
}

variable "gpt4o_capacity" {
  description = "Capacity in thousands of tokens-per-minute (TPM) for the GPT-4o deployment."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
