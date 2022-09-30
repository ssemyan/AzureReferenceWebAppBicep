// =========== main.bicep ===========
//
targetScope = 'subscription'

// params
@allowed([
  'dev'
  'stage'
  'prod'
])
param environ string = 'dev'

@allowed([
  'westeurope'
  'westus3'
])
param location string = 'westus3'

@description('AAD User ID to set as SQL admin')
param sqlAdminObjectId string

// Variables
var sqlAdminTenantId =  subscription().tenantId
var monitoringResourceGroupName = 'rg-monitoring-${environ}-${location}'
var networkingResourceGroupName = 'rg-networking-${environ}-${location}'
var databaseResourceGroupName = 'rg-database-${environ}-${location}'
var webResourceGroupName = 'rg-web-${environ}-${location}'
var storageResourceGroupName = 'rg-storage-${environ}-${location}'

// Lock the resources if we are creating the prod environment
var lockResources = (environ == 'prod') ? true : false

// Create RG if not already existing
resource monitorRG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: monitoringResourceGroupName
  location: location
}

resource networkingRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: networkingResourceGroupName
  location: location
}

resource databaseRG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: databaseResourceGroupName
  location: location
}

resource webRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: webResourceGroupName
  location: location
}

resource storageRG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: storageResourceGroupName
  location: location
}

// Create Monitoring
module monitoring './monitoring.bicep' = {
  name: 'monitoring'
  scope: monitorRG
  params: {
    environ: environ
    location: location
    lockResources: lockResources
  }
}

// Do Networking
module networking './networking.bicep' = {
  name: 'networking'
  scope: networkingRG
  params: {
    environ: environ
    location: location
    lockResources: lockResources
  }
}

// Do Database
module database './database.bicep' = {
  name: 'database'
  scope: databaseRG
  params: {
    environ: environ
    location: location
    lockResources: lockResources
    pvtLinkVnetId: networking.outputs.pvtLinkVnetId
    pvtLinkSubnetId: networking.outputs.pvtLinkSubnetId
    logAnalyticsGatewayId: monitoring.outputs.logAnalyticsAccountId
    diagnosticStorageAccountId: monitoring.outputs.diagnosticStorageAccountId
    sqlAdminTenantId: sqlAdminTenantId
    sqlAdminObjectId: sqlAdminObjectId
  }
}

// Do Storage
module storage './storage.bicep' = {
  name: 'storage'
  scope: storageRG
  params: {
    environ: environ
    location: location
    lockResources: lockResources
    pvtLinkVnetId: networking.outputs.pvtLinkVnetId
    pvtLinkSubnetId: networking.outputs.pvtLinkSubnetId
    logAnalyticsGatewayId: monitoring.outputs.logAnalyticsAccountId
    diagnosticStorageAccountId: monitoring.outputs.diagnosticStorageAccountId
  }
}

// Do Front Door Profile so we can pass ID to web
module fdProfile './frontDoorProfile.bicep' = {
  name: 'frontDoorProfile'
  scope: networkingRG
  params: {
    environ: environ
    location: location
    lockResources: lockResources
    logAnalyticsGatewayId: monitoring.outputs.logAnalyticsAccountId
    diagnosticStorageAccountId: monitoring.outputs.diagnosticStorageAccountId
  }
}

// Do Web
module website './web.bicep' = {
  name: 'website'
  scope: webRG
  params: {
    environ: environ
    location: location
    lockResources: lockResources
    frontDoorId: fdProfile.outputs.frontDoorId
    webSubnetId: networking.outputs.webSubnetId
    sqlServerName: database.outputs.sqlServerName
    sqlDbName: database.outputs.sqlDbName
    storageAccountName: storage.outputs.storageAccountName
    logAnalyticsGatewayId: monitoring.outputs.logAnalyticsAccountId
    diagnosticStorageAccountId: monitoring.outputs.diagnosticStorageAccountId
  }
}

// Do Storage Security to allow app service managed identity to access storage
module storageSec './stgsecurity.bicep' = {
  name: 'storageSec'
  scope: storageRG
  params: {
    environ: environ
    location: location
    managedIdPrincipalId: website.outputs.appSvcManagedIdPrincipalId
  }
}

// Set up front door proper
module frontDoor './frontDoor.bicep' = {
  name: 'frontDoor'
  scope: networkingRG
  params: {
    environ: environ
    location: location
    webHostName: website.outputs.appServiceHostName
  }
}
