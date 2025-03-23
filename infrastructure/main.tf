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

resource "azurerm_storage_account" "movies" {
  name = "stmovies${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.movies.name
  location = azurerm_resource_group.movies.location
  account_kind = "StorageV2"
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "movies" {
  name                  = "movie-posters"
  storage_account_id    = azurerm_storage_account.movies.id
  container_access_type = "private"
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

resource "azurerm_storage_account" "function-app" {
  name = "stfuncapp${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.movies.name
  location = azurerm_resource_group.movies.location
  account_kind = "StorageV2"
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "movies" {
  name = "asp-movies-${random_string.suffix.result}"
  location = azurerm_resource_group.movies.location
  resource_group_name = azurerm_resource_group.movies.name
  os_type = "Linux"
  sku_name = "Y1"
}

resource "azurerm_linux_function_app" "movies" {
  name                = "func-movies"
  resource_group_name = azurerm_resource_group.movies.name
  location            = azurerm_resource_group.movies.location

  storage_account_name       = azurerm_storage_account.function-app.name
  storage_account_access_key = azurerm_storage_account.function-app.primary_access_key
  service_plan_id = azurerm_service_plan.movies.id

  site_config {
    always_on = false
  }

  storage_account {
    account_name = azurerm_storage_account.function-app.name
    access_key   = azurerm_storage_account.function-app.primary_access_key
    name         = "func-storage"
    share_name   = "func-files"
    type         = "AzureBlob"
  }
}

resource "azurerm_cognitive_account" "ai_summary_service" {
  name = "ai-movie-summary-service-${random_integer.random_number.result}"
  location = azurerm_resource_group.movies.location
  resource_group_name = azurerm_resource_group.movies.name
  kind = "CognitiveServices"
  sku_name = "S0"
}
