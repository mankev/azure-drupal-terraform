#authentication and identification for Terraform
variable "my_client_secret"{
  type = string
}

variable "my_tenant_id"{
  type = string
}

variable "my_client_id"{
  type = string
}

variable "my_subscription_id"{
  type = string
}

variable "my_object_id"{
  type = string
}

#prefix for resources
variable "prefix" {

  description = "The prefix used for all resources in this example"
  default = "pokearoo"

}
# resource location
variable "location" {

  description = "The Azure location where all resources in this example should be created"
  default = "canadacentral"
}

# resource group name used by group resources
variable "rg" {

  description = "The resource group used for all resources in this example"

}

variable "tags" {
    type = map

    default = {
        Environment = "Terraform"
        Dept = "WebContentManagement"
        Owner = "goc"
        Project = "WOS_Drupal"
  }
}

#database
variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_sku" {
  type = string
  description = " The DB SKU name"

}
variable "db_location" {
  type = string
  description = " The DB SKU name"
}

variable "db_driver" {
  type = string
  description = " The DB driver type"
}

variable "db_name" {
  type = string
  description = " The DB name"
}

#keyvault
variable "key_vault_sku" {
  type = string
  description = " The Key Vault SKU name"
  default = "standard"

}
variable "key_vault_name" {
  type = string
  description = " The Key Vault  name"

}

variable "key_vault_resource_group_name" {
  type = string
  description = " The Key Vault  RG name"

}


