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