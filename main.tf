terraform {
  required_version = ">= 0.13"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.29.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.28.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }
  }
}
provider "azurerm" {
  features {}
}
resource "random_uuid" "app_roles_id" {
  for_each = { for r in var.app_roles : r.value => r }
}
data "azuread_client_config" "current" {}
data "azuread_application_template" "this" {
  display_name = "GitHub Enterprise Cloud - Organization" // use github org template
}
resource "azuread_application" "main" {
  display_name            = var.name
  template_id  = data.azuread_application_template.this.template_id // use template from above
  //identifier_uris         = ["https://github.com/orgs/danguyen-test3"]
  owners                  = [data.azuread_client_config.current.object_id]
  sign_in_audience        = var.sign_in_audience
  group_membership_claims = var.group_membership_claims
    web {
    homepage_url  = var.homepage
    //homepage_url = "https://github.com/orgs/danguyen-test"
    //redirect_uris = var.redirect_uris
    redirect_uris = ["https://github.com/orgs/danguyen-test3/saml/acs"]
    implicit_grant {
      access_token_issuance_enabled = var.access_token_issuance_enabled
      id_token_issuance_enabled     = var.id_token_issuance_enabled
    }
  }