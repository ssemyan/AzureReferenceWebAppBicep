# Introduction 
This is an Azure reference web application in Bicep with an attempt to follow architectural and security best practices. The application is an App Service hosted website that accesses Azure SQL and a storage account securely. 

![Architecture Diagram](https://github.com/ssemyan/AzureReferenceWebAppBicep/raw/master/ReferenceWebApp.png)

# Getting Started
To deploy, you need the Azure CLI installed and logged in. You also need the Bicep extensions. 

Versions used for this project:
Az CLI:   2.37.0
Az Bicep: 0.7.4

Resource names are created based on the environment and location. 

You can set the environment and location via the DEPLOY_ENV and DEPLOY_LOC environment variables. Example:
```
set DEPLOY_ENV=dev
set DEPLOY_LOC=westus2
```

Possible values for ENV are: 'dev' (default), 'stage', 'prod'

Possible values for LOC are: 'westeurope', 'westus3' (default)

## Azure SQL Admin
The admin account for the SQL DB can be set using the *DEPLOY_SQL_ADMIN* environment variable. If not explicitly set, it will be set to the account running the script. This can the object ID of an individual user or an Azure Active Directory group. 

Ensure you are logged into the proper subscription and you can then run the *BASH* script:
`./executeDeploy.sh`

This script first does a test run and shows what will be changed. To proceed, type 'y'. Any other character will stop the script. 

# Naming Conventions
General naming conventions follow the CAF [suggested naming best practice](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) and with consideration of the [naming rules and restrictions for Azure resources](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules).

## Template
`[resource-type]-[workload]-[environment]-[region]-[instance|unique id]`

## Naming Examples
#### Resource Group
rg-networking-prod-westus3

#### App Service (must be globally unique)
webapp-dev-westus3-v533jtdfiv52m

#### Storage (dashes not allowed, must be globally unique, limited to 24 characters)
stgdiagdevlog01

#### Managed Identities
id-webidentity-dev-westus3

# Resource Groups
The following Azure resource groups are created:

**rg-networking-dev-location**
Contains VNet, Front Door, and all associated networking components

**rg-appweb-dev-location, rg-adminweb-dev-location, rg-web-dev-location**
App Service and App Service Plans for websites

**rg-storage-dev-location**
Storage Account

**rg-database-dev-location**
Azure SQL Database and Servers

**rg-monitoring-dev-location**
Log Analytics workspace and storage account for long-term logs

# Developer Access to resources
Developers that need direct access to resources need to whitelist their IP addresses to get through the firewall.

# Managed Identity Access
The app service runs under a user assigned identity that is created as part of the script. This identity needs to be given access to the SQL database and the storage account. The storage account access happens as part of the script. The SQL access needs to be enabled as described below. 

## Azure SQL Access
Use the following script to give access to the identity in the SQL Database:
```
CREATE USER [<identity-name>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<identity-name>];
ALTER ROLE db_datawriter ADD MEMBER [<identity-name>];
GO
```
An example identity name is *id-webidentity-dev-westus3*

To use in code: 
`SqlConnection connection = new SqlConnection("Server=tcp:<server-name>.database.windows.net;Database=<database-name>;Authentication=Active Directory Managed Identity;User Id=<client-id-of-user-assigned-identity>;TrustServerCertificate=True");`

Reference: https://docs.microsoft.com/en-us/sql/connect/ado-net/sql/azure-active-directory-authentication?view=sql-server-ver16 

Note: this connection string is created by the Bicep script and added to the App Service configuration as *SqlConnectionString*

# Logging
All logs are sent to a single Log Analytics workspace (30 day retention) and storage account (180 day retention) in the monitoring resource group. 

# Security 
There are two aspects to security - connectivity and access. Connectivity is managed by IP restrictions and the use of Private Link. Access is managed by using Managed Identities for the App Service and then restricting the access of those identities. 

Service | Access | Authorization
--- | --- | ---
Website | Restricted to only allow access via the public IP address of the App Gateway. Integrated with the VNET containing the Private Links for Storage and the Database | The app service user-managed identity is given access to the storage accounts and database as described below. 
Storage | Access via Private Link or (for dev environment) IP restrictions (devs need to whitelist their IP addresses for access). In production, access should be via Private Link ONLY. | For the app, blob creation access is provided via a custom role. The managed identity is assigned to this role at the storage account level.
Database | Access via Private Link or (for dev environment) IP restrictions (devs need to whitelist their IP addresses for access). In production, access should be via Private Link ONLY. | Access to the DB is done by running the script in the *Azure SQL Access* section above.

# Deletion of deployment
There is a Bash script *deleteDeploy.sh* which allows for programmatic deletion of resources. Use with care. 

# TODO items for expansion
- Tagging of resources
- Enable Firewall for Front Door (requires upgrade to Front Door Premium) 
