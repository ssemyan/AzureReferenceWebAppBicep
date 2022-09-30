// params
param environ string 
param location string
param lockResources bool

@description('ID of the Front Door so we can restrict incoming traffic')
param frontDoorId string

@description('IDs of the subnet the app service should integrate to')
param webSubnetId string

@description('ID of the LogAnalytics Workspace to send diagnostics to')
param logAnalyticsGatewayId string

@description('ID of the Storage Account to send diagnostics to')
param diagnosticStorageAccountId string

@description('Name of the SQL Server for the app service settings')
param sqlServerName string

@description('Name of the SQL database for the app service settings')
param sqlDbName string

@description('Name of the storage account for the app service settings')
param storageAccountName string

var sqlConnectionStringName = 'SqlConnectionString'
var storageAccountStringName = 'StorageAccountName'

var appSvcDiagnosticStorageDays = 60
var autoScaleMaxInstances = '3'

var appServiceName = 'webapp-${environ}-${location}-${uniqueString(resourceGroup().id)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: 'svcplan-${environ}-${location}'
  location: location
  sku: {
    name: 'S1'
  }
}

resource appServicePlanScalings 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = {
  name: 'autoscale-${environ}-${location}'
  location: location
  properties: {
    enabled: true
    targetResourceLocation: location
    targetResourceUri: appServicePlan.id
    profiles: [
      {
        name: 'AppAutoScale'
        capacity: {
            minimum: '1'
            maximum: autoScaleMaxInstances
            default: '1'
        }
        rules: [
            {
                scaleAction: {
                    direction: 'Increase'
                    type: 'ChangeCount'
                    value: '1'
                    cooldown: 'PT5M'
                }
                metricTrigger: {
                    metricName: 'CpuPercentage'
                    metricNamespace: 'microsoft.web/serverfarms'
                    metricResourceUri: appServicePlan.id
                    operator: 'GreaterThan'
                    statistic: 'Average'
                    threshold: 70
                    timeAggregation: 'Average'
                    timeGrain: 'PT1M'
                    timeWindow: 'PT10M'
                    dividePerInstance: false
                }
            }
            {
                scaleAction: {
                    direction: 'Decrease'
                    type: 'ChangeCount'
                    value: '1'
                    cooldown: 'PT5M'
                }
                metricTrigger: {
                    metricName: 'CpuPercentage'
                    metricNamespace: 'microsoft.web/serverfarms'
                    metricResourceUri: appServicePlan.id
                    operator: 'GreaterThan'
                    statistic: 'Average'
                    threshold: 70
                    timeAggregation: 'Average'
                    timeGrain: 'PT1M'
                    timeWindow: 'PT10M'
                    dividePerInstance: false
                }
            }
       ] 
      }
    ]
  }
}

// User assigned identity resource
resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: 'id-webidentity-${environ}-${location}'
  location: location
}

// TODO: Add AAD Auth with redirect for non-logged in users
// REF: https://docs.microsoft.com/en-us/azure/architecture/example-scenario/private-web-app/private-web-app
resource appService 'Microsoft.Web/sites@2021-03-01' = {
  name: appServiceName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${msi.id}': {}
    }
  }
  properties: {
    httpsOnly: true
    serverFarmId: appServicePlan.id
    siteConfig: {
      vnetRouteAllEnabled: true
      ftpsState: 'Disabled'
      scmIpSecurityRestrictionsUseMain: false
      detailedErrorLoggingEnabled: true
      httpLoggingEnabled: true
      requestTracingEnabled: true
      minTlsVersion: '1.2'
      ipSecurityRestrictions: [
        {
          tag: 'ServiceTag'
          ipAddress: 'AzureFrontDoor.Backend'
          action: 'Allow'
          priority: 100
          headers: {
            'x-azure-fdid': [
              frontDoorId
            ]
          }
          name: 'Allow traffic from Front Door'
        }
      ]
      appSettings: [
        {
          name: sqlConnectionStringName
          value: 'Server=tcp:${sqlServerName}${environment().suffixes.sqlServerHostname};Database=${sqlDbName};Authentication=Active Directory Managed Identity;User Id=${msi.properties.clientId};TrustServerCertificate=True'
        }
        {
          name: storageAccountStringName
          value: storageAccountName
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: msi.properties.clientId
        }
      ]
    }
  }
}

resource vnweblock 'Microsoft.Authorization/locks@2017-04-01' = if (lockResources) {
  name: '${appServiceName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Resource should not be deleted'
  }
  scope: appService  
}

resource uiAppVnet 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  parent: appService
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: webSubnetId
    swiftSupported: true
  }
}

// Set up logging on the app service
resource appLogs 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'logs'
  parent: appService
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Information'
      }
    }
    detailedErrorMessages: {
      enabled: false
    }
    failedRequestsTracing: {
      enabled: false
    }
    httpLogs: {
      fileSystem: {
        enabled: true
        retentionInMb: 35
      }
    }
  }
}

// Set up logging to the log analytics account and storage
resource appServiceDiagnosticsLogs 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appService
  name: '${appServiceName}AppServiceLogAnalytics'
  properties: {
    workspaceId: logAnalyticsGatewayId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AppServicePlatformLogs'
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

resource appServiceDiagnosticsStorages 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appService
  name: '${appServiceName}AppServiceDiagnosticStorage'
  properties: {
    storageAccountId: diagnosticStorageAccountId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          days: appSvcDiagnosticStorageDays
          enabled: true
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          days: appSvcDiagnosticStorageDays
          enabled: true
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          days: appSvcDiagnosticStorageDays
          enabled: true
        }
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
        retentionPolicy: {
          days: appSvcDiagnosticStorageDays
          enabled: true
        }
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
        retentionPolicy: {
          days: appSvcDiagnosticStorageDays
          enabled: true
        }
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
        retentionPolicy: {
          days: appSvcDiagnosticStorageDays
          enabled: true
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

output appServiceHostName string = appService.properties.defaultHostName
output appSvcManagedIdPrincipalId string = msi.properties.principalId
