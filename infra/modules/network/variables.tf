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

variable "vnet_id" {
  description = "Resource ID of an existing VNet. Empty string creates a new VNet."
  type        = string
  default     = ""
}

variable "vnet_address_space" {
  description = "Address space for a new VNet (ignored when vnet_id is set)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "dev_vms_subnet_cidr" {
  description = "CIDR block for the 'dev-vms' subnet."
  type        = string
}

variable "ai_foundry_subnet_cidr" {
  description = "CIDR block for the 'ai-foundry' subnet."
  type        = string
}

variable "bastion_subnet_cidr" {
  description = "CIDR block for 'AzureBastionSubnet' (must be /26 or larger)."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
