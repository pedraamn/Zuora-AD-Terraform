This terraform creates an Azure AD enterprise app to pair with a github org for sso purposes.

users.csv contains the users to add to the enterprise app
terraform.tfvars contains the variables necessary to run this. These variables are the name of the
github org you want to pair the ad enterprise app with and the azure domain of your tenant.
You can find this in the Azure portal -> Azure Active Directory -> Overview -> Primary domain

If user creation is being handled in this terraform, this step must be done first: 
```
terraform apply -target azuread_user.csv_user
```
Otherwise, these users should already exist before we can add them to the enterprise app.

Apply rest of configuration to create the enterprise app and add the users to it

```
terraform apply
```