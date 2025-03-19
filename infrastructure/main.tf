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

resource "azurerm_resource_group" "movies" {
  name = "rg-movies-serverless-api"
  location = "centralus"
}

resource "random_integer" "random_number" {
  min = 1
  max = 5000
}

resource "random_string" "suffix" {
  length = 10
  upper = false
  special = false
}

resource "azurerm_storage_account" "movies-storage" {
  name = "stmovies${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.movies.name
  location = azurerm_resource_group.movies.location
  account_kind = "StorageV2"
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_cosmosdb_account" "movies-db" {
  name = "movies-cosmos-db-${random_integer.random_number.result}"
  location = azurerm_resource_group.movies.location
  resource_group_name = azurerm_resource_group.movies.name
  offer_type = "Standard"
  kind = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location = azurerm_resource_group.movies.location
    failover_priority = 0
  }
}

resource "azurerm_cognitive_account" "ai_summary_service" {
  name = "ai-movie-summary-service-${random_integer.random_number.result}"
  location = azurerm_resource_group.movies.location
  resource_group_name = azurerm_resource_group.movies.name
  kind = "CognitiveServices"
  sku_name = "S0"
}
