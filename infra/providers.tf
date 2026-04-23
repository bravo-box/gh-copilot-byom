terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

# Configure target cloud: 'usgovernment' for Azure Government, 'public' for Azure Commercial
provider "azurerm" {
  environment         = var.azure_environment
  storage_use_azuread = true
  features {}
}
