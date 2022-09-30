// params
param environ string 
param location string
param lockResources bool

@description('ID of the subnet for the private links')
param pvtLinkSubnetId string

@description('ID of the vnet for the private links')
param pvtLinkVnetId string

@description('ID of the LogAnalytics Workspace to send diagnostics to')
param logAnalyticsGatewayId string

@description('ID of the Storage Account to send diagnostics to')
param diagnosticStorageAccountId string

var storageName = 'stgapp${environ}we001'
var privateEndpointName = 'pvtep-${storageName}-${environ}-${location}-001'
var saStorageRetentionDays = 180

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties:{
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource vnweblock 'Microsoft.Authorization/locks@2017-04-01' = if (lockResources) {
  name: '${storageName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Resource should not be deleted'
  }
  scope: storageaccount  
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: pvtLinkSubnetId
    }
    privateLinkServiceConnections: [
      {
        properties: {
          privateLinkServiceId: storageaccount.id
          groupIds: [
            'blob'
          ]
        }
        name: 'PrivateEndpoint1'
      }
    ]
  }
}

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}' //  privatelink.blob.core.windows.net
  location: 'global'
  properties: {}
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${privateDnsZones.name}/${privateDnsZones.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: pvtLinkVnetId
    }
  }
}
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${privateEndpoint.name}/dnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZones.id
        }
      }
    ]
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' existing = {
  name: 'default'
  parent: storageaccount
}

resource storageAccountDiagnosticsLog 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobService
  name: 'blobStorageDiagnosticsLogAnalytics'
  properties: {
    workspaceId: logAnalyticsGatewayId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'Capacity'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

resource storageAccountDiagnosticsStorage 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobService
  name: 'blobStorageAccountDiagnosticsStorage'
  properties: {
    storageAccountId: diagnosticStorageAccountId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: saStorageRetentionDays
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: saStorageRetentionDays
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: saStorageRetentionDays
        }
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'Capacity'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

output storageAccountName string = storageName
