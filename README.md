We need to create ad groups and users before we can create group memberships

```
terraform apply -target azuread_user.csv_user
terraform apply -target azuread_group.csv_group
```

Apply rest of configuration to apply group memberships

```
terraform apply
```