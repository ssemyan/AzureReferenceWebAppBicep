// params
param environ string 
param location string
param lockResources bool

@description('ID of the LogAnalytics Workspace to send diagnostics to')
param logAnalyticsGatewayId string

@description('ID of the Storage Account to send diagnostics to')
param diagnosticStorageAccountId string

var frontDoorProfileName = 'fdp-${environ}-${location}-001'
var fdStorageRetentionDays = 180

resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
}

resource fdLock 'Microsoft.Authorization/locks@2017-04-01' = if(lockResources) {
  name: '${frontDoorProfileName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Resource should not be deleted'
  }
  scope: frontDoorProfile 
}

resource frontDoorDiagnosticsLog 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontDoorProfile
  name: 'frontDoorDiagnosticsLogAnalytics'
  properties: {
    workspaceId: logAnalyticsGatewayId
    logs: [
      {
        category: 'FrontDoorAccessLog'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'FrontDoorHealthProbeLog'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

resource frontDoorDiagnosticsStorage 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontDoorProfile
  name: 'frontDoorDiagnosticsStorage'
  properties: {
    storageAccountId: diagnosticStorageAccountId
    logs: [
      {
        category: 'FrontDoorAccessLog'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: fdStorageRetentionDays
        }
      }
      {
        category: 'FrontDoorHealthProbeLog'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: fdStorageRetentionDays
        }
      }
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: fdStorageRetentionDays
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

output frontDoorId string = frontDoorProfile.properties.frontDoorId
