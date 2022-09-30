// =========== main.bicep ===========
//
// Creates the log analytics workspace and storage account for logging
// 

// params
param environ string 
param location string
param lockResources bool

var logAnalyticsWorkspaceName = 'log-${environ}-${location}-01'
var storageName = 'stgdiag${environ}log01'
var logAnalyticsRetentionInDays = 30

// Set up the main workspace everything will go into
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018' // Pay as you go plan
    }
    retentionInDays: logAnalyticsRetentionInDays
  }
}

resource lalock 'Microsoft.Authorization/locks@2017-04-01' = if(lockResources) {
  name: '${logAnalyticsWorkspaceName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Resource should not be deleted'
  }
  scope: logAnalyticsWorkspace  
}

// Include a storage account for long term storage of logs
resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties:{
    allowBlobPublicAccess: false
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource salock 'Microsoft.Authorization/locks@2017-04-01' = if(lockResources) {
  name: '${storageName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Resource should not be deleted'
  }
  scope: storageaccount 
}

output logAnalyticsAccountId string = logAnalyticsWorkspace.id
output diagnosticStorageAccountId string = storageaccount.id
