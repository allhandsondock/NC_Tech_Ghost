targetScope = 'resourceGroup'

@minLength(3)
@maxLength(24)
param storageAccountName string

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
])
param storageAccountSku string



@description('Location to deploy the resources')
param location string = resourceGroup().location



// var resourceGroupName  = resourceGroup().name
// param filename string = 'routes.yaml'
// param destPath string = 'settings/routes.yaml'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageAccountSku
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
  }
}








output strgAccId string = storageAccount.id
