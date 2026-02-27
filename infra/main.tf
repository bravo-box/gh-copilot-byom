data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Network – VNet, subnets (dev-vms, ai-foundry, AzureBastionSubnet)
# ---------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  prefix                 = var.prefix
  location               = var.location
  resource_group_name    = var.resource_group_name
  vnet_id                = var.vnet_id
  vnet_address_space     = var.vnet_address_space
  dev_vms_subnet_cidr    = var.dev_vms_subnet_cidr
  ai_foundry_subnet_cidr = var.ai_foundry_subnet_cidr
  bastion_subnet_cidr    = var.bastion_subnet_cidr
  tags                   = var.tags
}

# ---------------------------------------------------------------------------
# Bastion – public IP and Azure Bastion host
# ---------------------------------------------------------------------------
module "bastion" {
  source = "./modules/bastion"

  prefix              = var.prefix
  location            = var.location
  resource_group_name = var.resource_group_name
  bastion_subnet_id   = module.network.bastion_subnet_id
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Data Science VM – Ubuntu DSVM in the dev-vms subnet
# ---------------------------------------------------------------------------
module "data_science_vm" {
  source = "./modules/data-science-vm"

  prefix              = var.prefix
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = module.network.dev_vms_subnet_id
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# AI Foundry – Azure OpenAI (GPT-4o) + AI Foundry Hub
# ---------------------------------------------------------------------------
module "ai_foundry" {
  source = "./modules/ai-foundry"

  prefix              = var.prefix
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = module.network.ai_foundry_subnet_id
  tenant_id           = data.azurerm_client_config.current.tenant_id
  openai_sku          = var.openai_sku
  gpt4o_capacity      = var.gpt4o_deployment_capacity
  tags                = var.tags
}
