targetScope = 'resourceGroup'

@description('Prefix to use when creating the resources in this deployment.')
param applicationNamePrefix string = 'ghost'

@description('App Service Plan pricing tier')
param appServicePlanSku string = 'B2'

@description('Log Analytics workspace pricing tier')
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('Storage account pricing tier')
param storageAccountSku string = 'Standard_LRS'

@description('Location to deploy the resources')
param location string = 'eastus'

@description('MySQL server SKU')
param mySQLServerSku string = 'Standard_B1ms'

@description('MySQL server password')
@secure()
param databasePassword string

@description('Ghost container full image name and tag')
param ghostContainerName string = 'allhandsondock/ghost-route:v8'

@description('Array of regions to deploy the resources')
param regions array = [
  'eastus2'
  'southcentralus'
]

@description('Array of resource group names corresponding to each region')
param resourceGroups array = [
  'pri1'
  'sec1'
]

@description('Container registry where the image is hosted')
param containerRegistryUrl string = 'https://index.docker.io/v1'

@allowed([
  'Web app only'
  'Web app with Azure Front Door'
  'afd'
])
param deploymentConfiguration string = 'afd'

@description('Virtual network address prefix to use')
param vnetAddressPrefix string = '10.0.0.0/26'
@description('Address prefix for web app integration subnet')
param webAppIntegrationSubnetPrefix string = '10.0.0.0/28'
@description('Address prefix for private links subnet')
param privateEndpointsSubnetPrefix string = '10.0.0.16/28'

var storageAccountName = 'strankgsfs'

var vNetNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-vnet-${i}-${uniqueString(resourceGroups[i])}']
var webAppNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-web-${i}-${uniqueString(resourceGroups[i])}']
var appServicePlanNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-asp-${i}-${uniqueString(resourceGroups[i])}']
var logAnalyticsWorkspaceNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-la-${i}-${uniqueString(resourceGroups[i])}']
var applicationInsightsNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-ai-${i}-${uniqueString(resourceGroups[i])}']
var keyVaultNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-kv-${i}-${uniqueString(resourceGroups[i])}']
var storageAccountNames = [for i in range(0, length(regions)): '${applicationNamePrefix}stor${i}-${uniqueString(resourceGroups[i])}']
var mySQLServerNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-mysql-${i}-${uniqueString(resourceGroups[i])}']
var functionAppNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-func-${i}-${uniqueString(resourceGroups[i])}']

module storageAccount 'modules/storageAccount copy.bicep' = [for i in range(0, length(regions)): {
  name: 'storageAccountDeploy-${i}'
  params: {
    storageAccountName: '${storageAccountName}${i}'
    storageAccountSku: storageAccountSku
   
    location: regions[i]
   
  }
 
  scope: resourceGroup(resourceGroups[i])
}]



output st1 string = storageAccount[0].name
output st2 string = storageAccount[1].name

output id1 string = storageAccount[0].outputs.strgAccId
output id2 string = storageAccount[1].outputs.strgAccId
