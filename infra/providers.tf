terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

# Azure Government cloud – USGov Arizona is the default region
provider "azurerm" {
  environment         = "usgovernment"
  storage_use_azuread = true
  features {}
}
