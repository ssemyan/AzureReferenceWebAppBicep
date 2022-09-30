// params
param environ string 
param location string

@description('Principal ID of the mandaged identity that needs access to the Storage Account')
param managedIdPrincipalId string

var stgRoleDefName = 'webrole-stgaccess-${environ}-${location}'
var stgRoleDefGuid = guid(stgRoleDefName)

// Set auth roles
resource roleDef 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
  name: stgRoleDefGuid
  properties: {
    roleName: stgRoleDefName
    description: 'Allow access for web identity'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/read'
          'Microsoft.Storage/storageAccounts/blobServices/containers/write'
          'Microsoft.Storage/storageAccounts/read'
        ]
        dataActions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write'
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action'
        ]
        notDataActions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'
        ]
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: resourceGroup()
  name: guid('${stgRoleDefName}-managedidassign')
  properties: {
    roleDefinitionId: roleDef.id
    principalId: managedIdPrincipalId
    principalType: 'ServicePrincipal'
  }
}
