resource "random_uuid" "spa_admin_roled_id" {}
resource "random_uuid" "spa_user_roled_id" {}
data "azuread_client_config" "current" {} 
resource "azuread_application" "spa_application" {
  display_name                                = "sampleEnterpriseApp"
  /*single_page_application {
    redirect_uris                         = [
    "https://yourdomain.com/"
    ]
  }*/
  
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
}

# Creating the service principal for spa app
resource "azuread_service_principal" "spa_app_sp" {
  application_id = azuread_application.spa_application.application_id
  preferred_single_sign_on_mode = "saml"

  feature_tags {
    enterprise = true
    gallery    = false
    custom_single_sign_on = true
  }
  owners                       = [data.azuread_client_config.current.object_id] // sets whoever's running the tf as the owner, must include this line here too
}

//hardcoded user for testing
resource "azuread_user" "example" {
  user_principal_name = "kdelgado@danxargmail.onmicrosoft.com"
  display_name        = "Karina Delgado"
  mail_nickname       = "kdelgado"
  password            = "SecretP@sswd99!"
}

# User Groups & Roles (hardcoded example)
# Create an ad group which can have access to SPA application
resource "azuread_group" "app_admin_group" {
  display_name    = "spa-app-admin-group"
  security_enabled = true

  members = [
    azuread_user.example.object_id,
  ]
}

resource "azuread_group" "app_user_group" {
  display_name    = "spa-app-user-group"
  security_enabled = true
}

# App role assignments
resource "azuread_app_role_assignment" "app_admin_role" {
  resource_object_id  = azuread_service_principal.spa_app_sp.object_id
  principal_object_id = azuread_group.app_admin_group.object_id
  app_role_id         = azuread_application.spa_application.app_role_ids["adminRole"]
}
resource "azuread_app_role_assignment" "app_user_role" {
  resource_object_id  = azuread_service_principal.spa_app_sp.object_id
  principal_object_id = azuread_group.app_user_group.object_id
  app_role_id         = azuread_application.spa_application.app_role_ids["userRole"]
}

#User groups (from csv)
locals {
  team_to_member = flatten([
    for user in csvdecode(file("users.csv")) : [
      {
        manager = user.manager
        UPN = user.UPN
      }
    ]
  ])
  // map of manager to team members. The important part is the unique manager, used to create groups
  team_to_member_map = {
    for pu in local.team_to_member :
    pu.manager => pu.UPN... // the elllipses means accept duplicate keys
  }

  // get object ids and group display name from the resource used to create the groups
  group_id_list = [
    for tn, t in azuread_group.csv_group : {
      id = t.id
      name = t.display_name
    }
  ]
  // map of group display name => group object id
  group_id_map = {
    for group in local.group_id_list : group.name => group.id
  }

  // get object ids and user principal name from the resource used to create the users
  user_id_list = [
    for tn, t in azuread_user.csv_user : {
      id = t.id
      display_name = t.display_name
      user_principal_name = t.user_principal_name
    }
  ]
  // map of user UPN => user's object id
  user_id_map = {
    for user in local.user_id_list : trimsuffix(user.user_principal_name, "@danxargmail.onmicrosoft.com") => user.id
  }
}

// create users from csv file
resource "azuread_user" "csv_user" {
  for_each = {
    for user in csvdecode(file("users.csv")) :
    user.UPN => user
  }
  user_principal_name = format("%s@danxargmail.onmicrosoft.com",each.value.UPN)
  display_name        = format("%s %s",each.value.first_name,each.value.last_name)
  mail_nickname       = each.value.mail_nickname
  password            = "SecretP@sswd99!"
  force_password_change = true
}

output "example" {
  value = {
    for pu in local.team_to_member :
    pu.manager => pu.UPN... // the elllipses means accept duplicate keys
  }
}

// create groups from each manager
resource "azuread_group" "csv_group" {
  for_each = local.team_to_member_map
  display_name    = each.key
  security_enabled = true
}

output "grouplistoutput" {
  value = local.group_id_list
}
output "groupmapoutput" {
  value = local.group_id_map
}
output "usermapoutput" {
  value = local.user_id_map
}
output "teammembersmap" {
  value = local.team_to_member_map

}

// apply a group membership for each user in the file
resource "azuread_group_member" "group_membership" {
  for_each = {
    for user in csvdecode(file("users.csv")) :
    user.UPN => user
  }
  // look up object ids for groups and members
  group_object_id  = local.group_id_map[each.value.manager]
  member_object_id = local.user_id_map[each.value.UPN]
}

