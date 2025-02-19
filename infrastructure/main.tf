terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.19.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "movies-rg" {
  name = "movies-api-project"
  location = "Central US"
}

resource "random_integer" "random_number" {
  min = 1
  max = 5000
}

resource "azurerm_storage_account" "movies-storage" {
  name = "movies-storage-${random_integer.random_number.result}"
  resource_group_name = azurerm_resource_group.movies-rg.name
  location = azurerm_resource_group.movies-rg.location
  account_kind = "StorageV2"
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_cosmosdb_account" "movies-db" {
  name = "movies-cosmos-db-${random_integer.random_number.result}"
  location = azurerm_resource_group.movies-rg.location
  resource_group_name = azurerm_resource_group.movies-rg.name
  offer_type = "Standard"
  kind = "GlobalDocumentDB"
}

resource "azurerm_ai_services" "ai-movie-summary" {
  name = "ai-movie-summary-service-${random_integer.random_number.result}"
  location = azurerm_resource_group.movies-rg.location
  resource_group = azurerm_resource_group.movies-rg.name
  sku_name = "S1"
}