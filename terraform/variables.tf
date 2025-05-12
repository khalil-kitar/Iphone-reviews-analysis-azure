variable "subscription_id" {}

variable "resource_group_name" {
  default = "iphone_reviews"
}

variable "location" {
  default = "East US"
}

variable "location_sql" {
  default = "East US 2"
}

variable "storage_account_name" {
  default = "storagereviews"
}

variable "admin_login" {
  default = "admin_db"
}

variable "admin_password" {}

variable "databricks_access_token" {}

variable "databricks_domain" {
  default = "https://adb-7440065039813.13.azuredatabricks.net"
}

variable "databricks_cluster_id" {}

variable "containers_list" {
  default = [
    "reviews-us", "reviews-uk", "reviews-tr", "reviews-ind",
    "reviews-br", "reviews-gr", "reviews-it", "reviews-fr"
  ]
}
