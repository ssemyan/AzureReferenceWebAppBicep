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

# Ask for conf
read -p "Continue with deletion (y/n)?" CONT
if [ "$CONT" != "y" ]; then
  exit 0
fi

deleteRgIfExists () {
    if [ $(az group exists --name $1) = true ]; then
        echo 'Deleting Resource Group '$1
        az group delete -n $1 -y
    fi
}

deleteRgIfExists "rg-storage-$DEPLOY_ENV-$DEPLOY_LOC"
deleteRgIfExists "rg-database-$DEPLOY_ENV-$DEPLOY_LOC"
deleteRgIfExists "rg-web-$DEPLOY_ENV-$DEPLOY_LOC"
deleteRgIfExists "rg-networking-$DEPLOY_ENV-$DEPLOY_LOC"
deleteRgIfExists "rg-monitoring-$DEPLOY_ENV-$DEPLOY_LOC"

