provider "azurerm" {
  version = 2.80
  client_secret = var.my_client_secret
  tenant_id = var.my_tenant_id
  client_id = var.my_client_id
  subscription_id = var.my_subscription_id

  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }

}

# we can't use this and if used risk loosing our resource group
/*
resource "azurerm_resource_group" "main" {

  name     = "${var.prefix}-rg"

  location = var.location

}
*/

//Create the Key Vault


data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}



# Need a random number generator to create unique names
resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }

  byte_length = 8
}

#create the Key Vault
resource "azurerm_key_vault" "main" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.rg
  enabled_for_disk_encryption = true
  tenant_id                   = var.my_tenant_id
  soft_delete_enabled         = false
  purge_protection_enabled    = false

  sku_name = var.key_vault_sku


  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "main" {
  key_vault_id = azurerm_key_vault.main.id

#  tenant_id = var.my_tenant_id
#  object_id = var.my_object_id
 tenant_id = data.azurerm_client_config.current.tenant_id
 object_id = data.azurerm_client_config.current.object_id

  key_permissions = [
    "get",
  ]

  secret_permissions = [
   "set",
   "get",
   "delete",
   "list",
    ]

}

resource "azurerm_key_vault_access_policy" "main2" {
  key_vault_id = azurerm_key_vault.main.id

  tenant_id = var.my_tenant_id
   object_id = azurerm_app_service.main.identity[0].principal_id

  key_permissions = [
    "get",
  ]

  secret_permissions = [
   "set",
   "get",
   "delete",
   "list",
    ]

}

resource "azurerm_key_vault_secret" "dbusername" {
  name         = "db-username"
  value        = var.db_username
  key_vault_id = azurerm_key_vault.main.id
  # there is an implicit dependancy on the key vault but none on the access policy so we create an explicit one below
  depends_on = [azurerm_key_vault_access_policy.main]
  tags = var.tags
}
resource "azurerm_key_vault_secret" "dbpassword" {
  name         = "db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.main.id
  # there is an implicit dependancy ion the key vault but none on the access policy so we create an explicit one below
  depends_on = [azurerm_key_vault_access_policy.main]
  tags = var.tags
}


// Create the AppService plan
resource "azurerm_app_service_plan" "main" {

  name                = "${var.prefix}-wos"
  location            = var.location
  resource_group_name = var.rg
  kind                = "Linux"
  reserved            = true
  tags                = var.tags
  sku   {
      tier = "Standard"
      size = "S1"
    }
}

// Create the AppService App

resource "azurerm_app_service" "main" {

  name                = "${var.prefix}-appservice"
  location            = var.location
  resource_group_name = var.rg
  app_service_plan_id = azurerm_app_service_plan.main.id
  tags = var.tags
  site_config {
     linux_fx_version = "COMPOSE|${filebase64("docker-compose.yml")}"
    app_command_line = ""
  }
/*
  lifecycle {
    ignore_changes = [
      site_config.0.linux_fx_version # deployments are made outside of Terraform
    ]
  }
*/

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
  # these are not needed for docker hub and if used app-service assumes it is a private repo
  #  "DOCKER_REGISTRY_SERVER_USERNAME" = "@Microsoft.KeyVault(SecretUri=${data.azurerm_key_vault_secret.dbusername.id})"
  #  "DOCKER_REGISTRY_SERVER_URL" = "https://hub.docker.com/mankev/site-wxt_nginx"
  #  "DOCKER_REGISTRY_SERVER_PASSWORD" = "@Microsoft.KeyVault(SecretUri=${data.azurerm_key_vault_secret.dbpasswd.id})"
    "DB_PASSWORD" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.dbpassword.id})"
    "DB_USERNAME" = "drupal@drupalcon2"
    "DB_HOST" = "drupalcon2.postgres.database.azure.com"
    "DB_NAME" = azurerm_postgresql_database.main.name
    "DB_DRIVER" = "pgsql" 
  }
  identity {
    type = "SystemAssigned"
  }
  
 logs {
    http_logs {
     file_system {
        retention_in_days = 7
        retention_in_mb = 100
      }
    }
  }
  
}

resource "azurerm_app_service_slot" "master" {
  name                = "master"
  app_service_name    = azurerm_app_service.main.name
  location            = var.location
  resource_group_name = var.rg
  app_service_plan_id = azurerm_app_service_plan.main.id

    site_config {
     linux_fx_version = "COMPOSE|${filebase64("docker-compose.yml")}"
    app_command_line = ""
  }
    app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
    "DB_PASSWORD" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.dbpassword.id})"
    "DB_USERNAME" = "drupal@drupalcon2"
    "DB_HOST" = "drupalcon2.postgres.database.azure.com"
    "DB_NAME" = azurerm_postgresql_database.main.name
    "DB_DRIVER" = "pgsql" 
  }

  identity {
    type = "SystemAssigned"
  }

 logs {
    http_logs {
     file_system {
        retention_in_days = 7
        retention_in_mb = 100
      }
    }
  }
  
}

resource "azurerm_app_service_slot" "staging" {
  name                = "staging"
  app_service_name    = azurerm_app_service.main.name
  location            = var.location
  resource_group_name = var.rg
  app_service_plan_id = azurerm_app_service_plan.main.id

    site_config {
     linux_fx_version = "COMPOSE|${filebase64("docker-compose.yml")}"
    app_command_line = ""
  }
    app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
    "DB_PASSWORD" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.dbpassword.id})"
    "DB_USERNAME" = "drupal@drupalcon2"
    "DB_HOST" = "drupalcon2.postgres.database.azure.com"
    "DB_NAME" = azurerm_postgresql_database.main.name
    "DB_DRIVER" = "pgsql" 
  }

  identity {
    type = "SystemAssigned"
  }

 logs {
    http_logs {
     file_system {
        retention_in_days = 7
        retention_in_mb = 100
      }
    }
  }
  
}

resource "azurerm_app_service_slot" "dev" {
  name                = "dev"
  app_service_name    = azurerm_app_service.main.name
  location            = var.location
  resource_group_name = var.rg
  app_service_plan_id = azurerm_app_service_plan.main.id

    site_config {
     linux_fx_version = "COMPOSE|${filebase64("docker-compose.yml")}"
    app_command_line = ""
  }
    app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
    "DB_PASSWORD" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.dbpassword.id})"
    "DB_USERNAME" = "drupal@drupalcon2"
    "DB_HOST" = "drupalcon2.postgres.database.azure.com"
    "DB_NAME" = azurerm_postgresql_database.main.name
    "DB_DRIVER" = "pgsql" 
  }

  identity {
    type = "SystemAssigned"
  }

 logs {
    http_logs {
     file_system {
        retention_in_days = 7
        retention_in_mb = 100
      }
    }
  }
  
}


resource "azurerm_container_registry" "main" {
  name                     = "${var.prefix}acr"
  resource_group_name      = var.rg
  location                 = var.location
  sku                      = "Premium"
  admin_enabled            = true
   depends_on = [azurerm_app_service_plan.main]
}

resource "azurerm_role_assignment" "acr_role_main" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "reader"
  principal_id         = azurerm_app_service.main.identity[0].principal_id
  depends_on = [azurerm_container_registry.main]
}

resource "azurerm_role_assignment" "acr_role_master" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "reader"
  principal_id         = azurerm_app_service_slot.master.identity[0].principal_id
  depends_on = [azurerm_container_registry.main]
}

resource "azurerm_role_assignment" "acr_role_staging" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "reader"
  principal_id         = azurerm_app_service_slot.staging.identity[0].principal_id
  depends_on = [azurerm_container_registry.main]
}

resource "azurerm_role_assignment" "acr_role_dev" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "reader"
  principal_id         = azurerm_app_service_slot.dev.identity[0].principal_id
  depends_on = [azurerm_container_registry.main]
}

resource "azurerm_role_assignment" "acr_role_ubervm" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "Contributor"
  principal_id         = var.my_object_id 
  depends_on = [azurerm_container_registry.main]
}

resource "azurerm_role_definition" "main" {
  name        = "acr_rw"
  scope       = azurerm_container_registry.main.id
  description = "This is a custom role created via Terraform"

  permissions {
    actions     = ["*"]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_container_registry.main.id,
  ]
}
# Create the database server
resource "azurerm_postgresql_server" "main" {
  name                = "${var.prefix}-postgresql"
  location            = var.db_location
  resource_group_name = var.rg
  sku_name = var.db_sku
  storage_mb            = 5120
  backup_retention_days = 7
  geo_redundant_backup_enabled  = false
  administrator_login          = azurerm_key_vault_secret.dbusername.value
  administrator_login_password = azurerm_key_vault_secret.dbpassword.value
  version                      = "11"
  ssl_enforcement_enabled      = true
}

// Create the database

resource "azurerm_postgresql_database" "main" {
  name                = var.db_name
  resource_group_name = var.rg
  server_name         = azurerm_postgresql_server.main.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}



resource "azurerm_frontdoor" "drupalcon3" {
  name                                         = "drupalcon3Frontdoor"
  resource_group_name                          = var.rg
  enforce_backend_pools_certificate_name_check = true

  routing_rule {
    name               = "drupalcon3RoutingRule1"
    accepted_protocols = ["Http", "Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["drupalcon3FrontendEndpoint"]
    forwarding_configuration {
      forwarding_protocol = "HttpsOnly"
      backend_pool_name   = "drupalcon3BackendDefault"
    }
  }

  backend_pool_load_balancing {
    name = "drupalcon3LoadBalancingSettings"
    additional_latency_milliseconds =0
    sample_size = 4
    successful_samples_required = 2
  }

  backend_pool_health_probe {
    name = "drupalcon3HealthProbeSetting"
    path = "/"
    protocol = "Https"
    enabled = true
    probe_method = "GET"
  }

  backend_pool {
    name = "drupalcon3BackendDefault"
    backend {
      host_header = azurerm_app_service.main.default_site_hostname
      address     = azurerm_app_service.main.default_site_hostname
      http_port   = 80
      https_port  = 443
    }

    load_balancing_name = "drupalcon3LoadBalancingSettings"
    health_probe_name   = "drupalcon3HealthProbeSetting"
  }

  frontend_endpoint {
    name                              = "drupalcon3FrontendEndpoint"
    # use the default host name exported from the app service instance
    host_name                         = "drupalcon3Frontdoor.azurefd.net"
    custom_https_provisioning_enabled = false
    web_application_firewall_policy_link_id = azurerm_frontdoor_firewall_policy.main.id
  }

}

# The Front Door firewall policy


resource "azurerm_frontdoor_firewall_policy" "main" {
  name                              = "drupalcon3WafPolicy"
  resource_group_name               = var.rg
  enabled                           = true
  mode                              = "Prevention"
  redirect_url                      = "https://canada.ca"
  custom_block_response_status_code = 403
  custom_block_response_body        = "PGh0bWw+CjxoZWFkZXI+PHRpdGxlPkhlbGxvPC90aXRsZT48L2hlYWRlcj4KPGJvZHk+CkhlbGxvIHdvcmxkCjwvYm9keT4KPC9odG1sPg=="

  custom_rule {
    name                           = "onlycra"
    enabled                        = true
    priority                       = 100
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 10
    type                           = "MatchRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = true
      match_values       = ["198.103.184.76"]
    }
  }


  managed_rule {
    type    = "DefaultRuleSet"
      version = "1.0"
  }
}



