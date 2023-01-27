This creates enterprise applications and their service principles on Azure AD, then assigns users to their correct applications

The applications need to be created first, then their service principles, and then members can be added.

```
terraform apply -target azuread_application.spa_application
terraform apply -target azuread_service_principal.spa_app_sp
<group creation will go here>
```

Apply rest of configuration to apply memberships

```
terraform apply
```