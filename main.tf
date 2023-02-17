

module "app1" {
    source  = "./enterprise_app"
    azure_domain = var.azure_domain
    users_file_path = var.users_file_path
    managers_file_path = var.managers_file_path
    organization_name = "zuora-platform"
    

}

module "app2" {
    source  = "./enterprise_app"
    azure_domain = var.azure_domain
    users_file_path = var.users_file_path
    managers_file_path = var.managers_file_path
    organization_name = "zuora-collect"
}

module "app3" {
    source  = "./enterprise_app"
    azure_domain = var.azure_domain
    users_file_path = var.users_file_path
    managers_file_path = var.managers_file_path
    organization_name = "zuora-billing"
}

module "app4" {
    source  = "./enterprise_app"
    azure_domain = var.azure_domain
    users_file_path = var.users_file_path
    managers_file_path = var.managers_file_path
    organization_name = "zuora-revenue-core"
}

module "app5" {
    source  = "./enterprise_app"
    azure_domain = var.azure_domain
    users_file_path = var.users_file_path
    managers_file_path = var.managers_file_path
    organization_name = "zuora-zcloud"
}

module "ad_users_and_groups" {
    source  = "./ad_users_and_groups"
    azure_domain = var.azure_domain
    users_file_path = var.users_file_path
    managers_file_path = var.managers_file_path
    groups_file_path = var.groups_file_path
    existing_groups_file_path = var.existing_groups_file_path
}