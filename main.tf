module "app1" {
    source  = "./enterprise_app"
    //version = "1.0.0"
    users_file_path = "./users.csv"
    azure_domain = "@zuoracloudeng.onmicrosoft.com"
    organization_name = "zuora-platform"
}

module "app2" {
    source  = "./enterprise_app"
    //version = "1.0.0"
    users_file_path = "./users.csv"
    azure_domain = "@zuoracloudeng.onmicrosoft.com"
    organization_name = "zuora-collect"
}

module "app3" {
    source  = "./enterprise_app"
    //version = "1.0.0"
    users_file_path = "./users.csv"
    azure_domain = "@zuoracloudeng.onmicrosoft.com"
    organization_name = "zuora-billing"
}

module "app4" {
    source  = "./enterprise_app"
    //version = "1.0.0"
    users_file_path = "./users.csv"
    azure_domain = "@zuoracloudeng.onmicrosoft.com"
    organization_name = "zuora-revenue-core"
}

module "app5" {
    source  = "./enterprise_app"
    //version = "1.0.0"
    users_file_path = "./users.csv"
    azure_domain = "@zuoracloudeng.onmicrosoft.com"
    organization_name = "zuora-zcloud"
}