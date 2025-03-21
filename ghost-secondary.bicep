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
param location string = resourceGroup().location

@description('MySQL server password')
@secure()
param databasePassword string

@description('Ghost container full image name and tag')
param ghostContainerName string = 'allhandsondock/ghost-route:v8'

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

@description('Front door url')
param frontDoorUrl string

@description('MYSQL server name')
param mySQLServerName string


var vNetName = '${applicationNamePrefix}-vnet-${uniqueString(resourceGroup().id)}'
var privateEndpointsSubnetName = 'privateEndpointsSubnet'
var webAppIntegrationSubnetName = 'webAppIntegrationSubnet'
var webAppName = '${applicationNamePrefix}-web-${uniqueString(resourceGroup().id)}'
var appServicePlanName = '${applicationNamePrefix}-asp-${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = '${applicationNamePrefix}-la-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = '${applicationNamePrefix}-ai-${uniqueString(resourceGroup().id)}'
var keyVaultName = '${applicationNamePrefix}-kv-${uniqueString(resourceGroup().id)}'
var storageAccountName = '${applicationNamePrefix}stor${uniqueString(resourceGroup().id)}'
var functionAppName = '${applicationNamePrefix}-func-${uniqueString(resourceGroup().id)}'

var databaseLogin = 'ghost'
var databaseName = 'ghost'

var ghostContentFileShareName = 'contentfiles'
var ghostContentFilesMountPath = '/var/lib/ghost/content'



module vNet 'modules/virtualNetwork.bicep' = {
  name: 'vNetDeploy'
  params: {
    vNetName: vNetName
    vNetAddressPrefix: vnetAddressPrefix
    privateEndpointsSubnetName: privateEndpointsSubnetName
    privateEndpointsSubnetPrefix: privateEndpointsSubnetPrefix
    webAppIntegrationSubnetName: webAppIntegrationSubnetName
    webAppIntegrationSubnetPrefix: webAppIntegrationSubnetPrefix
    location: location
  }
}

module logAnalyticsWorkspace './modules/logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspaceDeploy'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: location
  }
}

module storageAccount 'modules/storageAccount.bicep' = {
  name: 'storageAccountDeploy'
  params: {
    storageAccountName: storageAccountName
    storageAccountSku: storageAccountSku
    fileShareFolderName: ghostContentFileShareName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
    vNetName: vNetName
    privateEndpointsSubnetName: privateEndpointsSubnetName
  }
  dependsOn: [
    vNet
    logAnalyticsWorkspace
  ]
}

module keyVault './modules/keyVault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: 'databasePassword'
    keyVaultSecretValue: databasePassword
    ghostApiKey: '' // Create an API key after ghost blog is provisioned and store in Keyvault. This is to create a placeholder in keyvault under secret name 'ghostAPIKey'
    ghostApiSecretName: 'ghostAPIKey'
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
    vNetName: vNetName
    privateEndpointsSubnetName: privateEndpointsSubnetName
    webAppName: webAppName
    fnAppName: functionAppName
  }
  dependsOn: [
    webApp
    functionApp
    vNet
    logAnalyticsWorkspace
  ]
}

module webApp './modules/webApp.bicep' = {
  name: 'webAppDeploy'
  params: {
    webAppName: webAppName
    appServicePlanName: appServicePlanName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    vNetName: vNetName
    webAppIntegrationSubnetName: webAppIntegrationSubnetName
  }
  dependsOn: [
   appServicePlan
    vNet
    logAnalyticsWorkspace
  ]
}

module webAppSettings 'modules/webAppSettings.bicep' = {
  name: 'webAppSettingsDeploy'
  params: {
    webAppName: webAppName
    containerRegistryUrl: containerRegistryUrl
    ghostContainerImage: ghostContainerName
    containerMountPath: ghostContentFilesMountPath
    mySQLServerName: mySQLServerName
    databaseName: databaseName
    databaseLogin: databaseLogin
    databasePasswordSecretUri: keyVault.outputs.secretUri
    siteUrl: frontDoorUrl
    applicationInsightsName: applicationInsightsName
    fileShareName: storageAccount.outputs.fileShareFullName
    storageAccountName: storageAccountName
  }
  
}

module appServicePlan './modules/appServicePlan.bicep' = {
  name: 'appServicePlanDeploy'
  params: {
    appServicePlanName: appServicePlanName
    appServicePlanSku: appServicePlanSku
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

module applicationInsights './modules/applicationInsights.bicep' = {
  name: 'applicationInsightsDeploy'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    webAppName: webAppName
  }
  dependsOn: [
    webApp
    logAnalyticsWorkspace
  ]
}





module functionApp 'modules/functionApps.bicep' = {
  name: 'functionAppDeploy'
  params: {
    funcAppName: functionAppName
    location: location
    azFuncAsp: webApp.outputs.serverFarmId
    storageAccName: storageAccountName
    vNetName: vNetName
    webAppIntegrationSubnetName: webAppIntegrationSubnetName
    
    
  }
  dependsOn: [
    appServicePlan
    logAnalyticsWorkspace
  ]
}

module azFuncAppSetting 'modules/functionAppSettings.bicep' =  {
  name: 'fnAppSetting'
  params:{
    fnAppName: functionAppName
    aiKey: applicationInsights.outputs.instKey
    storageAccountName: storageAccountName
    ghostUrl: 'https://${webApp.outputs.hostName}'
    ghostAPISecretUri: keyVault.outputs.ghostAPISecretUri
  }
  dependsOn:[
    functionApp
  ]
}

output webAppHostName string = webApp.outputs.hostName

