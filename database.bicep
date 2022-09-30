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

@description('ID AAD Tenant for the server admin')
param sqlAdminTenantId string

@description('ID of the AAD User to set as SQL admin')
param sqlAdminObjectId string

var sqlServerName = 'sqlsvr-${environ}-${location}-001'
var sqlDbName = 'sqldb-${environ}-${location}-001'
var privateEndpointName = 'pvtep-${sqlServerName}-${environ}-${location}-001'

var sqllogin = 'SQL-SRV-ADMIN'

var sqlStorageRetentionDays = 30

resource server 'Microsoft.Sql/servers@2021-11-01-preview' = {
  name: sqlServerName
  location: location
  identity: {
    type: 'None'
  }
  properties: {
    publicNetworkAccess: 'Enabled' // via firewall
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      principalType: 'Group'
      tenantId: sqlAdminTenantId
      login: sqllogin
      sid: sqlAdminObjectId
    }
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  parent: server
  name: sqlDbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 10
  }
}

resource dblock 'Microsoft.Authorization/locks@2017-04-01' = if(lockResources) {
  name: '${sqlDbName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Resource should not be deleted'
  }
  scope: sqlDB  
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
          privateLinkServiceId: server.id
          groupIds: [
            'sqlServer'
          ]
        }
        name: 'PrivateEndpoint1'
      }
    ]
  }
}

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}' //  privatelink.database.windows.net
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

resource dbDiagnosticsLog 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlDB
  name: 'sqlDiagnosticsLogAnalytics'
  properties: {
    workspaceId: logAnalyticsGatewayId
    logs: [
      {
        category: 'DevOpsOperationsAudit'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'Errors'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'SQLInsights'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AutomaticTuning'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'Timeouts'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'Blocks'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'Deadlocks'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'InstanceAndAppAdvanced'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'WorkloadManagement'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }    
    ]
  }
}

resource dbDiagnosticsStorage 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlDB
  name: 'sqlDiagnosticsStorage'
  properties: {
    storageAccountId: diagnosticStorageAccountId
    logs: [
      {
        category: 'DevOpsOperationsAudit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: sqlStorageRetentionDays
        }
      }
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: sqlStorageRetentionDays
        }
      }
      {
        category: 'Errors'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: sqlStorageRetentionDays
        }
      }
      {
        category: 'SQLInsights'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AutomaticTuning'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'Timeouts'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'Blocks'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'Deadlocks'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'InstanceAndAppAdvanced'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'WorkloadManagement'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }    
    ]
  }
}

output sqlServerName string = sqlServerName
output sqlDbName string = sqlDbName
