targetScope = 'resourceGroup'

//
// PARAMETERS
//
@description('Prefix to use when creating the resources in this deployment.')
param applicationNamePrefix string = 'ghost'

@description('App Service Plan pricing tier')
param appServicePlanSku array = [ 'B1', 'B2']

@description('Log Analytics workspace pricing tier')
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('Storage account pricing tier')
param storageAccountSku string = 'Standard_LRS'

@description('Array of regions to deploy the resources')
param regions array = [
  'northeurope' 
  'westeurope'
]

@description('Array of resource group names corresponding to each region')
param resourceGroups array = [
  'pp3'
  'ss3'
]


@description('MySQL server SKU')
param mySQLServerSku string = 'Standard_D2ads_v5'

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
param vnetAddressPrefix array = [
  '10.0.0.0/26'
  '172.16.0.0/26'
]

@description('Address prefix for web app integration subnet')
param webAppIntegrationSubnetPrefix array = [
'10.0.0.0/28'
'172.16.0.0/28'

]
@description('Address prefix for private links subnet')
param privateEndpointsSubnetPrefix array = [
'10.0.0.16/28'
'172.16.0.16/28'
]


//
// CONSTANTS & NAME GENERATION (per region)
//
var privateEndpointsSubnetName = 'privateEndpointsSubnet'
var webAppIntegrationSubnetName = 'webAppIntegrationSubnet'
var ghostContentFileShareName = 'contentfiles'
var ghostContentFilesMountPath = '/var/lib/ghost/content'

// Create per-region name arrays. We use the loop index and uniqueString based on the target resource group.
var vNetNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-vnet-${i}-${uniqueString(resourceGroups[i])}']
var webAppNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-web-${i}-${uniqueString(resourceGroups[i])}']
var appServicePlanNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-${uniqueString(resourceGroups[i])}']
var logAnalyticsWorkspaceNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-la-${i}-${uniqueString(resourceGroups[i])}']
var applicationInsightsNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-ai-${i}-${uniqueString(resourceGroups[i])}']
var keyVaultNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-kv-${i}-${uniqueString(resourceGroups[i])}']
var storageAccountNames = [for i in range(0, length(regions)): '${applicationNamePrefix}stor${i}${uniqueString(resourceGroups[i])}']
var mySQLServerNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-mysql-${i}-${uniqueString(resourceGroups[i])}']
var functionAppNames = [for i in range(0, length(regions)): '${applicationNamePrefix}-func-${i}-${uniqueString(resourceGroups[i])}']

// Front Door is deployed only in the primary region (index 0)
var frontDoorName = '${applicationNamePrefix}-fd-${uniqueString(resourceGroups[0])}'
var siteUrl = (deploymentConfiguration == 'Web app only')
  ? 'https://${frontDoor.outputs.frontDoorEndpointHostName}'
  : 'https://${webApp[0].outputs.hostName}'
//
// MODULE DEPLOYMENTS (loop over each region)
//

// 1. Virtual Network
module vNet 'modules/virtualNetwork.bicep' = [for i in range(0, length(regions)): {
  name: 'vNetDeploy-${i}'
  scope: resourceGroup(resourceGroups[i])
  params: {
    vNetName: vNetNames[i]
    vNetAddressPrefix: vnetAddressPrefix[i]
    privateEndpointsSubnetName: privateEndpointsSubnetName
    privateEndpointsSubnetPrefix: privateEndpointsSubnetPrefix[i]
    webAppIntegrationSubnetName: webAppIntegrationSubnetName
    webAppIntegrationSubnetPrefix: webAppIntegrationSubnetPrefix[i]
    location: regions[i]
  }
}]

// 2. Log Analytics Workspace
module logAnalyticsWorkspace './modules/logAnalyticsWorkspace.bicep' = [for i in range(0, length(regions)): {
  name: 'logAnalyticsWorkspaceDeploy-${i}'
  scope: resourceGroup(resourceGroups[i])
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[i]
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: regions[i]
  }
}]

// 3. Storage Account (with file share)
module storageAccount 'modules/storageAccount.bicep' = [for i in range(0, length(regions)): {
  name: 'storageAccountDeploy-${i}'
  scope: resourceGroup(resourceGroups[i])
  params: {
    storageAccountName: storageAccountNames[i]
    storageAccountSku: storageAccountSku
    fileShareFolderName: ghostContentFileShareName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[i]
    location: regions[i]
    vNetName: vNetNames[i]
    privateEndpointsSubnetName: privateEndpointsSubnetName
  }
  dependsOn: [
    vNet[i]
    logAnalyticsWorkspace[i]
  ]
}]

// 4. App Service Plan
module appServicePlan './modules/appServicePlan.bicep' = [for i in range(0, length(regions)): {
  name: 'appServicePlanDeploy${i}'
  scope: resourceGroup(resourceGroups[i])
  params: {
    appServicePlanName: appServicePlanNames[i]
    appServicePlanSku: appServicePlanSku[i]
    location: regions[i]
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[i]
  }
  dependsOn: [
    logAnalyticsWorkspace[i]
  ]
}]

// module appServicePlan './modules/appServicePlan.bicep' = {
//   name: 'appServicePlanDeploy11'
//   scope: resourceGroup(resourceGroups[0])
//   params: {
//     appServicePlanName: appServicePlanNames[0]
//     appServicePlanSku: appServicePlanSku[0]
//     location: regions[0]
//     logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[0]
//   }
//   dependsOn: [
//     logAnalyticsWorkspace[0]
//   ]
// }

// module appServicePlan2 './modules/appServicePlan.bicep' = {
//   name: 'appServicePlanDeploy22'
//   scope: resourceGroup(resourceGroups[1])
//   params: {
//     appServicePlanName: appServicePlanNames[1]
//     appServicePlanSku: appServicePlanSku[1]
//     location: regions[1]
//     logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[1]
//   }
//   dependsOn: [
//     appServicePlan
//     logAnalyticsWorkspace[1]
//   ]
// }

// 5. Web App
module webApp './modules/webApp.bicep' = [for i in range(0, length(regions)): {
  name: 'webAppDeploy-${i}'
  scope: resourceGroup(resourceGroups[i])
  params: {
    webAppName: webAppNames[i]
    appServicePlanName: appServicePlanNames[i]
    location: regions[i]
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[i]
    vNetName: vNetNames[i]
    webAppIntegrationSubnetName: webAppIntegrationSubnetName
  }
  dependsOn: [
    appServicePlan[i]
    vNet[i]
    logAnalyticsWorkspace[i]
  ]
}]

// 6. Application Insights
module applicationInsights './modules/applicationInsights.bicep' = [for i in range(0, length(regions)): {
  name: 'applicationInsightsDeploy-${i}'
  scope: resourceGroup(resourceGroups[i])
  params: {
    applicationInsightsName: applicationInsightsNames[i]
    location: regions[i]
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[i]
    webAppName: webAppNames[i]
  }
  dependsOn: [
    webApp[i]
    logAnalyticsWorkspace[i]
  ]
}]

// 7. MySQL Server
module mySQLServer 'modules/mySQLServer.bicep' = {
  name: 'mySQLServerDeploy'
  scope: resourceGroup(resourceGroups[0])
  params: {
    administratorLogin: 'ghost'
    administratorPassword: databasePassword
    location: regions[0]
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[0]
    mySQLServerName: mySQLServerNames[0]
    mySQLServerSku: mySQLServerSku
    vNetName: vNetNames[0]
    privateEndpointsSubnetName: privateEndpointsSubnetName
  }
  dependsOn: [
    vNet[0]
    logAnalyticsWorkspace[0]
  ]
}

module mySQLServerReplica 'modules/mySQLServer-replica.bicep' = {
  name: 'mySQLServerDeploy-replica'
  scope: resourceGroup(resourceGroups[0])
  params: {
    administratorLogin: 'ghost'
    administratorPassword: databasePassword
    location: regions[1]
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[0]
    mySQLServerName: mySQLServerNames[1]
    sourceServerId: mySQLServer.outputs.mysqlId
    mySQLServerSku: mySQLServerSku
  }
  dependsOn: [
    vNet[0]
    vNet[1]
    logAnalyticsWorkspace[0]
  ]
}

// configure network for the replica
module mySQLServerReplicaNetwork 'modules/mySQLServer-replica-network.bicep' = {
  name: 'mySQLServerDeploy-replica-network'
  scope: resourceGroup(resourceGroups[1])
  params: {
    location: regions[1]
    mysqlServerId: mySQLServerReplica.outputs.mysqlId
    vNetName: vNetNames[1]
    privateEndpointsSubnetName: privateEndpointsSubnetName
  }
  dependsOn: [
    vNet[0]
    vNet[1]
    logAnalyticsWorkspace[0]
  ]
}

// Configure PEP and DNS for primary SQL server on secondary vnet
module mySQLServerNetwork 'modules/mySQLServer-network.bicep' = {
  name: 'mySQLServerDeploy-network'
  scope: resourceGroup(resourceGroups[1])
  params: {
    location: regions[1]
    mysqlServerId: mySQLServer.outputs.mysqlId
    vNetName: vNetNames[1]
    privateEndpointsSubnetName: privateEndpointsSubnetName
  }
  dependsOn: [
    vNet[1]
    logAnalyticsWorkspace[0]
  ]
}


// 8. Function App
module functionApp 'modules/functionApps.bicep' = [for i in range(0, length(regions)): {
  name: 'functionAppDeploy-${i}'
  scope: resourceGroup(resourceGroups[i])
  params: {
    funcAppName: functionAppNames[i]
    location: regions[i]
    azFuncAsp: webApp[i].outputs.serverFarmId
    storageAccName: storageAccountNames[i]
    vNetName: vNetNames[i]
    webAppIntegrationSubnetName: webAppIntegrationSubnetName
  }
  dependsOn: [
    appServicePlan[i]
    webApp[i]
    logAnalyticsWorkspace[i]
  ]
}]

// 9. Function App Settings
module azFuncAppSetting 'modules/functionAppSettings.bicep' = [for i in range(0, length(regions)): {
  name: 'fnAppSetting-${i}'
  scope: resourceGroup(resourceGroups[i])
  params:{
    fnAppName: functionAppNames[i]
    aiKey: applicationInsights[i].outputs.instKey
    storageAccountName: storageAccountNames[i]
    ghostUrl: 'https://${webApp[i].outputs.hostName}'
    ghostAPISecretUri: keyVault[i].outputs.ghostAPISecretUri
  }
  dependsOn:[
    functionApp[i]
    webApp[i]
    keyVault[i]
  ]
}]

// 10. Key Vault
module keyVault './modules/keyVault.bicep' = [for i in range(0, length(regions)): {
  name: 'keyVaultDeploy-${i}'
  scope: resourceGroup(resourceGroups[i])
  params: {
    keyVaultName: keyVaultNames[i]
    keyVaultSecretName: 'databasePassword'
    keyVaultSecretValue: databasePassword
    ghostApiKey: '' // Placeholder for ghost API key
    ghostApiSecretName: 'ghostAPIKey'
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[i]
    location: regions[i]
    vNetName: vNetNames[i]
    privateEndpointsSubnetName: privateEndpointsSubnetName
    webAppName: webAppNames[i]
    fnAppName: functionAppNames[i]
  }
  dependsOn: [
    webApp[i]
    functionApp[i]
    vNet[i]
    logAnalyticsWorkspace[i]
  ]
}]

// 11. Web App Settings (uses outputs from storageAccount and keyVault deployed in each region)
module webAppSettings 'modules/webAppSettings.bicep' = [for i in range(0, length(regions)): {
  name: 'webAppSettingsDeploy-${i}'
  scope: resourceGroup(resourceGroups[i])
  params: {
    webAppName: webAppNames[i]
    containerRegistryUrl: containerRegistryUrl
    ghostContainerImage: ghostContainerName
    containerMountPath: ghostContentFilesMountPath
    mySQLServerName: mySQLServerNames[0]
    databaseName: 'ghost'
    databaseLogin: 'ghost'
    databasePasswordSecretUri: keyVault[i].outputs.secretUri
    siteUrl: siteUrl
    applicationInsightsName: applicationInsightsNames[i]
    fileShareName: storageAccount[i].outputs.fileShareFullName
    storageAccountName: storageAccountNames[i]
    resourceGroupName: resourceGroups[0]
  }
  dependsOn: [
    frontDoor
    mySQLServer
    webApp[i]
    keyVault[i]
  ]
}]

// Optionally, if deploymentConfiguration is 'afd', deploy Front Door only in the primary region (index 0)
module frontDoor 'modules/frontDoor.bicep' = if (deploymentConfiguration == 'afd') {
  name: 'FrontDoorDeploy'
  scope: resourceGroup(resourceGroups[0]) 
  params: {
    frontDoorProfileName: frontDoorName
    applicationName: applicationNamePrefix
    webAppName: '${applicationNamePrefix}-web-0-${uniqueString(resourceGroups[0])}'
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceNames[0]
  }
  dependsOn: [
    webApp[0]
    logAnalyticsWorkspace[0]
  ]
}

// //
// // OUTPUTS
// //
// // output webAppHostNames array = [for w in webApp: w.outputs.hostName]
// // output endpointHostName string = deploymentConfiguration == 'afd'
// //   ? 'https://${frontDoor.outputs.frontDoorEndpointHostName}'
// //   : webApp.outputs[0].hostName
// // output mysqlNames array = [for m in mySQLServer: m.outputs.mysqlurl]
