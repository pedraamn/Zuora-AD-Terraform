variable "azure_domain"{}
variable "users_file_path"{}
variable "managers_file_path"{}
variable "groups_file_path"{}
variable "existing_groups_file_path"{}

#User groups (from csv)
locals {
    users = csvdecode(file(var.users_file_path))
    groups = csvdecode(file(var.groups_file_path))
    existing_groups = csvdecode(file(var.existing_groups_file_path))
    managers = csvdecode(file(var.managers_file_path))

    // maps each individual bucket to all of the AD groups that fall under
    bucket_to_groups = flatten([
        for row in local.groups : [
            {
                bucket = row.bucket
                group = row.name
            }
        ]
    ])

    bucket_to_groups_map = {
        for pu in local.bucket_to_groups :
            pu.bucket => pu.group... // the elllipses means accept duplicate keys
    }


    // get object ids and group display name from the resource used to create the groups
    group_id_list = [
        for tn, t in azuread_group.csv_group : {
            id = t.id
            name = t.display_name
        }
    ]

    // map of group display name => group object id
     group_to_id_map = {
        for group in local.group_id_list :
            group.name => group.id
    }

    // maps each individual bucket to all of the AD groups that fall under
    bucket_to_existing_groups = flatten([
        for row in local.existing_groups : [
            {
                bucket = row.bucket
                group = row.name
            }
        ]
    ])

    bucket_to_existing_groups_map = {
        for pu in local.bucket_to_existing_groups :
            pu.bucket => pu.group... // the elllipses means accept duplicate keys
    }

    existing_group_to_id_map = {
        for group in local.existing_groups :
            group.name => group.id
    }

    // maps managers to the bucket users under them are added
    manager_to_bucket_map = {
        for manager in local.managers :
            manager.upn => manager.bucket
    }

    // grabs existing users object id
    existing_user_id_list = [
        for tn, t in data.azuread_user.existing_users : {
            id = t.id
            display_name = t.display_name
            user_principal_name = t.user_principal_name
        }
    ]

    existing_user_id_map = {
        for user in local.existing_user_id_list :
            trimsuffix(user.user_principal_name, var.azure_domain) => user.id
    }

    // create string pairs of user_ids -> groups_ids in which they are to be added
    user_group_id_pairs = flatten ([
        for user in local.users : [
            for group in local.bucket_to_groups_map[local.manager_to_bucket_map[user.manager]] :
                format("%s %s", local.existing_user_id_map[user.upn], local.group_to_id_map[group])
        ]
    ])
    
    // create string pairs of user_ids -> groups_ids in which they are to be added
    user_existing_group_id_pairs = flatten ([
        for user in local.users : [
            for group in local.bucket_to_existing_groups_map[local.manager_to_bucket_map[user.manager]] :
                format("%s %s", local.existing_user_id_map[user.upn], local.existing_group_to_id_map[group])
        ]
    ])

    user_group_id_pairs_final = concat(local.user_group_id_pairs, local.user_existing_group_id_pairs)
}


output "testing1" {
    value = local.groups
}
// create groups_ids
resource "azuread_group" "csv_group" {
  groups = csvdecode(file(var.groups_file_path))
  for_each = {for group in local.groups : group.name => group}
  display_name = each.value.name
  owners = ["76b0dd23-772e-4e9f-9001-7a1c1e2f824b"]
  security_enabled = true
}


// get existing users
data "azuread_user" "existing_users" {
  for_each = {for user in local.users : user.upn => user}
  user_principal_name = format("%s%s", each.value.upn, var.azure_domain)
}

// apply group membership to users
resource "azuread_group_member" "group_membership" {
  for_each = {for user in local.user_group_id_pairs_final: user => user}
  // look up object ids for groups and members
  member_object_id = split(" ", each.value)[0]
  group_object_id  = split(" ", each.value)[1]
}


output "printer3" {
    value = local.manager_to_bucket_map
}

output "printer6" {
    value = local.users
}

output "printer7" {
    value = local.existing_user_id_map
}

output "printer8" {
    value = local.user_group_id_pairs
}

output "printer9" {
    value = local.bucket_to_existing_groups
}
