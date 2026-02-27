# ---------------------------------------------------------------------------
# Core configuration
# ---------------------------------------------------------------------------

variable "prefix" {
  description = "Short prefix prepended to every resource name (e.g. 'byom')."
  type        = string
  default     = "byom"

  validation {
    condition     = length(var.prefix) >= 2 && length(var.prefix) <= 10 && can(regex("^[a-z0-9-]+$", var.prefix))
    error_message = "prefix must be 2-10 lowercase alphanumeric characters or hyphens."
  }
}

variable "location" {
  description = "Azure Government region in which to deploy all resources (e.g. 'usgovarizona', 'usgovvirginia')."
  type        = string
  default     = "usgovarizona"
}

variable "resource_group_name" {
  description = "Name of the pre-existing Azure Resource Group."
  type        = string
}

variable "tags" {
  description = "Map of tags applied to every resource."
  type        = map(string)
  default = {
    project     = "gh-copilot-byom"
    environment = "dev"
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Network configuration
# ---------------------------------------------------------------------------

variable "vnet_id" {
  description = <<-EOT
    Resource ID of an existing Virtual Network to attach to.
    Leave empty ("") to have Terraform create a new VNet.
    Example: "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>"
  EOT
  type        = string
  default     = ""
}

variable "vnet_address_space" {
  description = "Address space for the new VNet. Only used when vnet_id is empty."
  type        = string
  default     = "10.0.0.0/16"
}

variable "dev_vms_subnet_cidr" {
  description = "CIDR block for the 'dev-vms' subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "ai_foundry_subnet_cidr" {
  description = "CIDR block for the 'ai-foundry' subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "bastion_subnet_cidr" {
  description = "CIDR block for the 'AzureBastionSubnet'. Must be at least /26."
  type        = string
  default     = "10.0.255.0/27"
}

variable "block_internet_outbound" {
  description = "When set to true, NSG rules are applied to block virtual machines from reaching the public internet."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Data Science VM configuration
# ---------------------------------------------------------------------------

variable "vm_size" {
  description = "Azure VM SKU for the Data Science Virtual Machine."
  type        = string
  default     = "Standard_DS3_v2"
}

variable "admin_username" {
  description = "Administrator username for the Data Science VM."
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Administrator password for the Windows Data Science VM."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# AI Foundry / OpenAI configuration
# ---------------------------------------------------------------------------

variable "openai_sku" {
  description = "Pricing tier for the Azure OpenAI Cognitive Services account."
  type        = string
  default     = "S0"
}

variable "gpt4o_deployment_capacity" {
  description = "Capacity in thousands of tokens-per-minute (TPM) for the GPT-4o deployment."
  type        = number
  default     = 10
}
