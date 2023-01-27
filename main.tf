resource "random_uuid" "spa_admin_roled_id" {}
resource "random_uuid" "spa_user_roled_id" {}
data "azuread_client_config" "current" {} 

variable "azure_domain"{}

locals {
  # users from csv file
  users = flatten([
    for user in csvdecode(file("users.csv")) : [
      {
        UPN = user.UPN
        organization = user.organization
        team = user.manager
      } 
    ]
  ])
  users_map = { for user in local.users : user.UPN => user }

  // map of team to team members. The important part is the unique team name, used to create groups
  team_to_members_map = {
    for item in local.users :
    item.team => item.UPN... // the elllipses means accept duplicate keys
  }

  // map of organization to team members
  org_to_members_map = {
    for user in local.users :
    user.organization => user.UPN... // the elllipses means accept duplicate keys
  }

  // get list of enterprise apps created
  enterprise_apps_list = [
    for tn, t in azuread_application.spa_application : {
      id = t.application_id
      name = t.display_name
      userRole = t.app_role_ids["userRole"]
    }
  ]
  // map of enterprise apps with name as the key value
  enterprise_apps_map = {
    for app in local.enterprise_apps_list : app.name => app
  }

    // get service principles that were created
  service_principle_id_list = [
    for tn, t in azuread_service_principal.spa_app_sp : {
      id = t.id
      application_name = trimsuffix(trimprefix(t.login_url, "https://github.com/orgs/"), "/sso")
    }
  ]
  // map of service principle => its object id
  service_principle_id_map = {
    for sp in local.service_principle_id_list : sp.application_name => sp.id
  }


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

    // get object ids and group display name from the resource used to create the groups
  group_id_list = [
    for tn, t in azuread_group.group : {
      id = t.id
      name = t.display_name
    }
  ]
  // map of group display name => group object id
  group_id_map = {
    for group in local.group_id_list : group.name => group.id
  }
}

data "azuread_application_template" "this" {
  display_name = "GitHub Enterprise Cloud - Organization" // use github org template currently not working properly
}

resource "azuread_application" "spa_application" {
  for_each = local.org_to_members_map
  display_name                                = each.key
  template_id  = data.azuread_application_template.this.template_id
  /*single_page_application {
    redirect_uris                         = [
    "https://yourdomain.com/"
    ]
  }*/

    web {
    redirect_uris = [
      format("https://github.com/orgs/%s/saml/consume",each.key),
    ]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = false
    }
  }
  
  
  //identifier_uris = [
  //  "https://github.com/orgs/danguyen-test6",
  //]
  
  //identifier_uris                     = ["https://yourdomain.com"]
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
      identifier_uris
    ]
  }
}
output "service_principle_map" {
  value = local.service_principle_id_map
}
output "enterprise_apps_map" {
  value = local.enterprise_apps_map
}
/*
output "user_id_map" {
  value = local.existing_user_id_map
}*/

# Create the service principals for the apps
resource "azuread_service_principal" "spa_app_sp" {
  for_each = local.enterprise_apps_map
  //application_id = azuread_application.spa_application.application_id
  application_id = local.enterprise_apps_map[each.key].id
  use_existing   = true // use exisiting service principle that comes from the template
  preferred_single_sign_on_mode = "saml"
  login_url                     = format("https://github.com/orgs/%s/sso",each.key)
  app_role_assignment_required  = true

  feature_tags {
    enterprise = true
    gallery    = false
    custom_single_sign_on = true
  }
  owners                       = [data.azuread_client_config.current.object_id] // sets whoever's running the tf as the owner, must include this line here too
}



// get existing users
data "azuread_user" "existing_users" {
  for_each = {
    for user in csvdecode(file("users.csv")) :
    user.UPN => user
  } 
  user_principal_name = "${each.value.UPN}${var.azure_domain}"
}

// create groups from each team
resource "azuread_group" "group" {
  for_each = local.team_to_members_map
  display_name    = each.key
  security_enabled = true
}

// apply a group membership for each user
resource "azuread_group_member" "group_membership" {
  for_each = local.users_map
  // look up object ids for groups and members
  group_object_id  = local.group_id_map[each.value.team]
  member_object_id = local.existing_user_id_map[each.value.UPN]
}


// add all users to the correct enterprise app
resource "azuread_app_role_assignment" "user_roles" {
  for_each = local.users_map
  //resource_object_id  = azuread_service_principal.spa_app_sp.object_id
  resource_object_id = local.service_principle_id_map[each.value.organization]
  principal_object_id = local.existing_user_id_map[each.value.UPN]
  //app_role_id         = azuread_application.spa_application.app_role_ids["userRole"]
  app_role_id = local.enterprise_apps_map[each.value.organization].userRole
}
