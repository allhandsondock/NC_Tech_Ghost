targetScope = 'resourceGroup'

param mysqlServerId string
param location string = resourceGroup().location


// Configuring private endpoint
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to create a private endpoint')
param privateEndpointsSubnetName string
var privateEndpointName = 'ghost-pl-mysql-sec-rep-${uniqueString(resourceGroup().id)}'
var privateDnsZoneName = 'privatelink.mysql.database.azure.com'
var pvtEndpointDnsGroupName = '${privateEndpointName}/mysql'

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vNetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  
  name: privateEndpointsSubnetName
  parent: existingVNet
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: existingSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: mysqlServerId
          groupIds: [
            'mysqlServer'
          ]
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01'  existing = {
  
  name: privateDnsZoneName

}

resource privateDnsZoneName_privateDnsZoneName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${existingVNet.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: existingVNet.id
    }
  }
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  name: pvtEndpointDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}

