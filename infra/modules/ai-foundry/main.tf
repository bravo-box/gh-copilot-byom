# Random suffix to guarantee globally-unique resource names.
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ---------------------------------------------------------------------------
# Supporting infrastructure required by AI Foundry Hub
# ---------------------------------------------------------------------------

# Storage account – used by AI Foundry for experiment artifacts
resource "azurerm_storage_account" "ai_foundry" {
  # Storage account names: 3-24 lowercase alphanumeric characters
  name                     = "${replace(var.prefix, "-", "")}st${random_string.suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# Key Vault – stores secrets/keys for AI Foundry
resource "azurerm_key_vault" "ai_foundry" {
  name                       = "${var.prefix}-kv-${random_string.suffix.result}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags
}

# ---------------------------------------------------------------------------
# Azure OpenAI Service
# ---------------------------------------------------------------------------

resource "azurerm_cognitive_account" "openai" {
  name                = "${var.prefix}-openai-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = var.openai_sku
  tags                = var.tags
}

# GPT-4o model deployment
resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-08-06"
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.gpt4o_capacity
  }
}

# ---------------------------------------------------------------------------
# Azure AI Foundry Hub
# ---------------------------------------------------------------------------

resource "azurerm_ai_foundry" "main" {
  name                = "${var.prefix}-foundry-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  storage_account_id  = azurerm_storage_account.ai_foundry.id
  key_vault_id        = azurerm_key_vault.ai_foundry.id

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
