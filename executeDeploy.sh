#!/bin/bash

# Stop on errors, unset variables, and pass back the error code
set -eu pipefail

# Script to deploy bicep resources to Azure
# Assumes runner is already logged into Azure and has contribute role

# Need to have environ and location set in env variables but overriding with 'dev' and 'westus3' below
if [[ -v DEPLOY_ENV ]]; then
  echo 'Using environment: '$DEPLOY_ENV
else
  DEPLOY_ENV='dev'
  echo 'Environment not set. Defaulting to : '$DEPLOY_ENV
fi

if [[ -v DEPLOY_LOC ]]; then
  echo 'Using location: '$DEPLOY_LOC
else
  DEPLOY_LOC='westus3'
  echo 'Location not set. Defaulting to : '$DEPLOY_LOC
fi

# If user ID for SQL Admin not passed in, use current user
if [[ -v DEPLOY_SQL_ADMIN ]]; then
  echo 'Using SQL Admin ID: '$DEPLOY_SQL_ADMIN
else
  echo 'SQL Admin ID not set. Trying to obtain object ID of current user...'
  DEPLOY_SQL_ADMIN=$(az ad signed-in-user show --query id -o tsv)
  echo 'SQL Admin not set. Defaulting to : '$DEPLOY_SQL_ADMIN
fi

# Create unique name for deployment
deploymentName='WD_Deployment_'$DEPLOY_ENV'_'$DEPLOY_LOC'_'$(date +"%Y%m%d%H%M%S")
echo "New deployment: $deploymentName"

# Show active subscription
echo ''
echo 'Active Subscription: '
echo ''
az account show -o table

# Deploy
echo ''
echo "Testing Deployment"
echo ''
az deployment sub create --name $deploymentName --location $DEPLOY_LOC --template-file main.bicep --parameters environ=$DEPLOY_ENV location=$DEPLOY_LOC sqlAdminObjectId=$DEPLOY_SQL_ADMIN -w

# Ask for conf
read -p "Continue with deploy (y/n)?" CONT
if [ "$CONT" != "y" ]; then
  exit 0
fi

echo ''
echo 'Deploying...'
echo ''
az deployment sub create --name $deploymentName --location $DEPLOY_LOC --template-file main.bicep --parameters environ=$DEPLOY_ENV location=$DEPLOY_LOC sqlAdminObjectId=$DEPLOY_SQL_ADMIN
