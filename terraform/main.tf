provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "storagereviews" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "RAGRS"
  allow_nested_items_to_be_public = false
}

resource "azurerm_databricks_workspace" "reviews_transformation" {
  name                = "reviews-transformation"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "standard"
}

resource "azurerm_mssql_server" "server_reviews" {
  name                         = "server-reviews"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.location_sql
  version                      = "12.0"
  administrator_login          = var.admin_login
  administrator_login_password = var.admin_password
}

resource "azurerm_mssql_database" "reviews_db" {
  name                  = "reviews_db"
  server_id             = azurerm_mssql_server.server_reviews.id
  storage_account_type  = "Local"
}

resource "azurerm_data_factory" "orchestration_service" {
  name                = "orchestration-service"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_data_factory_linked_service_azure_databricks" "AzureDatabricksconnection2" {
  name                = "AzureDatabricksconnection2"
  data_factory_id     = azurerm_data_factory.orchestration_service.id
  description         = "ADB Linked Service via Access Token"
  access_token        = var.databricks_access_token
  existing_cluster_id = var.databricks_cluster_id
  adb_domain          = var.databricks_domain
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "AzureBlobStorage1" {
  name              = "AzureBlobStorage1"
  data_factory_id   = azurerm_data_factory.orchestration_service.id
  description       = "Linked Service to Azure Blob Storage"
  connection_string = "" 
}

resource "azurerm_data_factory_dataset_azure_blob" "binary1" {
  name                 = "binary1"
  data_factory_id      = azurerm_data_factory.orchestration_service.id
  linked_service_name  = azurerm_data_factory_linked_service_azure_blob_storage.AzureBlobStorage1.name
  path                 = "@items"
}

resource "azurerm_data_factory_pipeline" "reviews_analysis_pipeline" {
  name            = "reviews-analysis-pipeline"
  data_factory_id = azurerm_data_factory.orchestration_service.id

  activities_json = jsonencode([
    {
      name              = "Notebook1"
      type              = "DatabricksNotebook"
      dependsOn         = []
      linkedServiceName = {
        referenceName = azurerm_data_factory_linked_service_azure_databricks.AzureDatabricksconnection2.name
        type          = "LinkedServiceReference"
      }
      typeProperties = {
        notebookPath = "//Transformation_df"
      }
      policy = {
        retry                  = 0
        retryIntervalInSeconds = 30
        secureInput            = false
        secureOutput           = false
        timeout                = "0.12:00:00"
      }
      userProperties = []
    },
    {
      name      = "ForEach1"
      type      = "ForEach"
      dependsOn = [{
        activity             = "Notebook1"
        dependencyConditions = ["Succeeded"]
      }]
      typeProperties = {
        items = {
          type  = "Expression"
          value = "@variables('containersList')"
        }
        activities = [{
          name = "Delete1"
          type = "Delete"
          dependsOn = []
          typeProperties = {
            dataset = {
              referenceName = azurerm_data_factory_dataset_azure_blob.binary1.name
              type          = "DatasetReference"
            }
            storeSettings = {
              type = "AzureBlobStorageReadSettings"
              linkedServiceName = {
                referenceName = azurerm_data_factory_linked_service_azure_blob_storage.AzureBlobStorage1.name
                type          = "LinkedServiceReference"
              }
              recursive                = true
              enablePartitionDiscovery = false
            }
          }
          policy = {
            retry                  = 0
            retryIntervalInSeconds = 30
            secureInput            = false
            secureOutput           = false
            timeout                = "0.12:00:00"
          }
          userProperties = []
        }]
      }
      userProperties = []
    }
  ])

  variables = {
    containersList = jsonencode(var.containers_list)
  }
}

resource "azurerm_data_factory_trigger_blob_event" "trigger" {
  name                  = "new-data"
  data_factory_id       = azurerm_data_factory.orchestration_service.id
  storage_account_id    = azurerm_storage_account.storagereviews.id
  events                = ["Microsoft.Storage.BlobCreated"]
  blob_path_begins_with = "ready-flag/ready"
  ignore_empty_blobs    = false
  activated             = true

  pipeline {
    name = azurerm_data_factory_pipeline.reviews_analysis_pipeline.name
  }
}

# Create blob containers dynamically
resource "azurerm_storage_container" "containers" {
  for_each              = toset(var.containers_list)
  name                  = each.key
  storage_account_name  = azurerm_storage_account.storagereviews.name
  container_access_type = "private"
}

# Additional containers
resource "azurerm_storage_container" "data_quality_reports" {
  name                  = "data-quality-reports"
  storage_account_name  = azurerm_storage_account.storagereviews.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "processed_data" {
  name                  = "processed-data"
  storage_account_name  = azurerm_storage_account.storagereviews.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "ready_flag" {
  name                  = "ready-flag"
  storage_account_name  = azurerm_storage_account.storagereviews.name
  container_access_type = "private"
}
