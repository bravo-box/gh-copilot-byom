variable "project_name" {
  description = "Project name used as a prefix for all resources. Must be lowercase letters, numbers, and hyphens only (no spaces)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_name)) && !strcontains(var.project_name, " ")
    error_message = "project_name must start and end with a lowercase letter or digit, and contain only lowercase letters, numbers, and hyphens (no spaces)."
  }
}

variable "location" {
  description = "Azure Government region in which to deploy all resources."
  type        = string
  default     = "usgovarizona"
}

variable "vnet_address_space" {
  description = "CIDR block for the virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_virtual_machines_prefix" {
  description = "CIDR prefix for the virtual-machines subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_aoai_prefix" {
  description = "CIDR prefix for the aoai subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_bastion_prefix" {
  description = "CIDR prefix for the AzureBastionSubnet (minimum /27 required by Bastion)."
  type        = string
  default     = "10.0.3.0/27"
}

variable "subnet_storage_prefix" {
  description = "CIDR prefix for the storage private endpoint subnet."
  type        = string
  default     = "10.0.4.0/24"
}

variable "vm_size" {
  description = "SKU size for the Windows Data Science VM."
  type        = string
  default     = "Standard_DS3_v2"
}

variable "vm_admin_username" {
  description = "Local administrator username for the Windows Data Science VM."
  type        = string
  default     = "dsadmin"
}

variable "vm_admin_password" {
  description = "Local administrator password for the Windows Data Science VM. Must meet Azure complexity requirements."
  type        = string
  sensitive   = true
}

variable "aoai_sku" {
  description = "SKU for the Azure OpenAI Cognitive Services account."
  type        = string
  default     = "S0"
}

variable "model_deployment_name" {
  description = "Name to give the GPT-5.2 model deployment inside Azure OpenAI."
  type        = string
  default     = "gpt-51"
}

variable "model_token_capacity" {
  description = "Tokens-per-minute (TPM) capacity in thousands for the GPT-5.1 deployment."
  type        = number
  default     = 10
}

variable "custom_vm_image_id" {
  description = "Resource ID of a custom managed image (built by Packer). When set, the VM uses this image instead of the marketplace DSVM image."
  type        = string
  default     = null
}

variable "storage_replication_type" {
  description = "Replication type for the storage account (LRS, ZRS, GRS, etc.)."
  type        = string
  default     = "LRS"
}
