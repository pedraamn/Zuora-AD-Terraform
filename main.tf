module "terraform_test_module" {
    source  = "./enterprise_app"
    //version = "1.0.0"
    users_file_path = "./users.csv"
    azure_domain = "@danxargmail.onmicrosoft.com"
    organization_name = "danguyen-demo-org7"
}

module "terraform_test_module2" {
    source  = "./enterprise_app"
    //version = "1.0.0"
    users_file_path = "./users.csv"
    azure_domain = "@danxargmail.onmicrosoft.com"
    organization_name = "danguyen-demo-org8"
}