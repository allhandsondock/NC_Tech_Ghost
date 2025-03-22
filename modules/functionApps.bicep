
param azFuncAsp string
param funcAppName string
param location string
param storageAccName string

resource ghostbackend 'Microsoft.Web/sites@2022-03-01' =  {
  name: funcAppName
  kind: 'functionapp'
  location: location
  properties: {
    enabled: true
    publicNetworkAccess: 'Disabled'
    serverFarmId: azFuncAsp
    siteConfig: {
      numberOfWorkers: 1
      linuxFxVersion: ''
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 200
      minimumElasticInstanceCount: 0
    }
   

    httpsOnly: true
    redundancyMode: 'None'
   
    storageAccountRequired: true
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccName
}

// Assign Storage Blob Data Contributor Role to Function App Identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ghostbackend.name, 'StorageBlobDataOwner')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner Role
    principalId: ghostbackend.identity.principalId
  }
}

// Configuring virtual network integration
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to integrate web app')
param webAppIntegrationSubnetName string

resource existingvNet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vNetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  name: webAppIntegrationSubnetName
  parent: existingvNet
}

resource webApp_vNetIntegration 'Microsoft.Web/sites/networkConfig@2023-12-01' = {
  parent: ghostbackend
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: existingSubnet.id
  }
  
}

output azFuncMI string = ghostbackend.identity.principalId
output tenant string = ghostbackend.identity.tenantId
