resource "random_uuid" "spa_admin_roled_id" {}
resource "random_uuid" "spa_user_roled_id" {}
data "azuread_client_config" "current" {} 
variable "organization_name"{}
variable "azure_domain"{}
variable "users_file_path"{}

locals {
  # users from csv file
  users = flatten([
    for user in csvdecode(file(var.users_file_path)) : [
      {
        UPN = user.UPN
        organization = user.organization
        //team = user.team
      } 
    ] if user.organization == var.organization_name
    // only look at users that belong to this organization
  ])
  users_map = { for user in local.users : user.UPN => user }

  // get object ids and user principal name from the resource used to find existing users
  existing_user_id_list = [
    for tn, t in data.azuread_user.existing_users : {
      id = t.id
      display_name = t.display_name
      user_principal_name = t.user_principal_name
    }
  ]
  // map of user UPN => user's object id for existing users 
  existing_user_id_map = {
    for user in local.existing_user_id_list : trimsuffix(user.user_principal_name, var.azure_domain) => user.id
  }
}

data "azuread_application_template" "this" {
  display_name = "GitHub Enterprise Cloud - Organization" // use github org template currently not working properly
}

resource "azuread_application" "spa_application" {
  display_name                                = var.organization_name
  template_id  = data.azuread_application_template.this.template_id
  /*single_page_application {
    redirect_uris                         = [
    "https://yourdomain.com/"
    ]
  }*/

    web {
    redirect_uris = [
      format("https://github.com/orgs/%s/saml/consume",var.organization_name),
    ]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = false
    }
  }
  
  // identifier_uris                     = ["https://yourdomain.com"]
  // identifier uris can't be set here initially because azure complains that it has
  // to be a verified domain name. Instead, we leave this blank and include this
  // field in the ignore_changes lifecycle  field at the bottom of this reseource
  // so it may be set manually without the terraform forcing it to change back to blank
  sign_in_audience                    = "AzureADMyOrg"
  group_membership_claims             = [ "SecurityGroup" ]

  optional_claims {
    access_token {
      name                  = "groups"
      source                = null
      essential             = false
      additional_properties = []
    }

    id_token {
      name                  = "groups"
      source                = null
      essential             = false
      additional_properties = []
    }
  }

  app_role {
    allowed_member_types = ["User"] # Specifies whether this app role definition can be assigned to users and groups by setting to User, or to other applications (that are accessing this application in a standalone scenario) by setting to Application, or to both.
    description          = "Admin Role"
    display_name         = "adminRole"
    enabled              = true
    id                   = random_uuid.spa_admin_roled_id.result
    value                = "adminRole"
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "User Role"
    display_name         = "userRole"
    enabled              = true
    id                   = random_uuid.spa_user_roled_id.result
    value                = "userRole"
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    # Note: Role permissions display as Application and scope permissions display as Delegated in the Azure portal
    # these resource access ids can be found online. A list can be found here: https://rollendxavier.medium.com/how-to-manage-an-application-registration-within-azure-active-directory-using-terraform-4014923aefba
    resource_access {
      id   = "bdfbf15f-ee85-4955-8675-146e8e5296b5" //AAD Application.ReadWrite.All
      type = "Scope"
    }
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" //AAD User.Read
      type = "Scope"
    }
  }

  lifecycle {
    ignore_changes = [
      identifier_uris // allow this field to be set manually
    ]
  }
}

# Create the service principal for the app
resource "azuread_service_principal" "spa_app_sp" {
  application_id = azuread_application.spa_application.application_id
  use_existing   = true // use exisiting service principle that comes from the template
  preferred_single_sign_on_mode = "saml"
  login_url                     = format("https://github.com/orgs/%s/sso",var.organization_name)
  app_role_assignment_required  = true

  feature_tags {
    enterprise = true
    gallery    = false
    custom_single_sign_on = true
  }
  owners                       = [data.azuread_client_config.current.object_id] // sets whoever's running the tf as the owner
}

// get existing users
data "azuread_user" "existing_users" {
  for_each = local.users_map
  user_principal_name = "${each.value.UPN}${var.azure_domain}"
}

// add all users that belong to this enterprise app
resource "azuread_app_role_assignment" "user_roles" {
  for_each = local.users_map
  resource_object_id  = azuread_service_principal.spa_app_sp.object_id
  principal_object_id = local.existing_user_id_map[each.value.UPN]
  app_role_id = azuread_application.spa_application.app_role_ids["userRole"]
}
