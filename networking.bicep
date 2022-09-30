// params
param environ string 
param location string
param lockResources bool

var vnetWebName = 'vnet-web-${environ}-${location}-001'
var vnetWebAddressRoot = '10.2'
var subnetWebName = 'WebSubnet'
var subnetPrivLinkName = 'PrivateLinkSubnet'

resource virtualNetworkWeb 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: vnetWebName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '${vnetWebAddressRoot}.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetWebName
        properties: {
          addressPrefix: '${vnetWebAddressRoot}.2.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnetPrivLinkName
        properties: {
          addressPrefix: '${vnetWebAddressRoot}.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource vnweblock 'Microsoft.Authorization/locks@2017-04-01' = if(lockResources) {
  name: '${vnetWebName}-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Resource should not be deleted'
  }
  scope: virtualNetworkWeb  
}

output webSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetWebName, subnetWebName)
output pvtLinkSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetWebName, subnetPrivLinkName)
output pvtLinkVnetId string = virtualNetworkWeb.id
