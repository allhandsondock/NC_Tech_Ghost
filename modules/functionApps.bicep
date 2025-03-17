
param azFuncAsp string
param funcAppName string
param location string
param isPrimary bool
param storageAccName string

resource ghostbackend 'Microsoft.Web/sites@2022-03-01' = if(isPrimary) {
  name: funcAppName
  kind: 'functionapp'
  location: location
  properties: {
    enabled: true
   
   
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
  name: guid(ghostbackend.name, 'StorageBlobDataContributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Contributor Role
    principalId: ghostbackend.identity.principalId
  }
}

output azFuncMI string = ghostbackend.identity.principalId
output tenant string = ghostbackend.identity.tenantId
