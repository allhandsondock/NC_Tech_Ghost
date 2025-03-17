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

@description('File share to store Ghost content files')
param fileShareFolderName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

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

resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource storageAccountDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: 'StorageAccountDiagnostics'
  properties: {
    workspaceId: existingWorkspace.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileServicesDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: fileServices
  name: 'FileServicesDiagnostics'
  properties: {
    workspaceId: existingWorkspace.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileServices
  name: fileShareFolderName
}

// Configuring private endpoint
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to create a private endpoint')
param privateEndpointsSubnetName string

var privateEndpointName = 'ghost-pl-file-${uniqueString(resourceGroup().id)}'
var privateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'
var pvtEndpointDnsGroupName = '${privateEndpointName}/file'

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vNetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  name: privateEndpointsSubnetName
  parent: existingVNet
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
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
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
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
// End of configuring private endpoint

// resource uploadScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
//   name: 'uploadFileScript'
//   location: location
//   kind: 'AzurePowerShell'
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${scriptIdentity.id}': {}
//     }
//   }
//   properties: {
//     azPowerShellVersion: '7.2'
//     arguments: '-resourceGroupName ${resourceGroup().name} -storageAccountName ${storageAccountName} -fileShareFolderName ${fileShareFolderName}'
//     scriptContent: '''
//     param(
//         [string]$resourceGroupName,
//         [string]$storageAccountName,
//         [string]$fileShareFolderName
//       )

//       $ghoststorageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
//       $context = $ghoststorageAccount.Context
//       New-AzStorageDirectory -ShareName $fileShareFolderName -Path 'settings' -Context $context -ErrorAction SilentlyContinue
//       Set-AzStorageFileContent -ShareName $fileShareFolderName -Source './routes.yaml' -Path 'settings/routes.yaml' -Context $context
//     '''
//      retentionInterval: 'PT1H'
//     cleanupPreference: 'OnSuccess'
//   }
//   dependsOn: [
//     fileShare
//     dataReaderRoleAssignment
//   ]
// }

// resource uploadScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
//   name: 'uploadFileScript'
//   location: location
//   kind: 'AzureCLI'
//   properties: {
//     azCliVersion: '2.40.0'
//     timeout: 'PT5M'
//     retentionInterval: 'PT1H'
//     environmentVariables: [
//       {
//         name: 'AZURE_STORAGE_ACCOUNT'
//         value: storageAccount.name
//       }
//       {
//         name: 'AZURE_STORAGE_KEY'
//         secureValue: storageAccount.listKeys().keys[0].value
//       }
//       {
//         name: 'CONTENT'
//         value: loadTextContent('./routes.yaml')
//       }
//     ]
//     scriptContent: '''
    
//     az storage directory create --name settings -s ${fileShareFolderName}
//     echo "$CONTENT" > ${filename} && az storage file upload --source ${filename} -s ${fileShareFolderName} -p ${destPath}

//     '''
//   }
//   dependsOn: [
//     fileShare
//     dataReaderRoleAssignment
//   ]
// }


// @description('The Storage Reader Role definition from [Built In Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles).')
// resource storageBlobDataReaderRoleDef 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
//   scope: subscription()
//   name: 'c12c1c16-33a1-487b-954d-41c89c60f349'
// }

// @description('The Storage Blob Data Reader Role definition from [Built In Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles).')
// resource storageFileDataContributorRoleDef 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
//   scope: subscription()
//   name: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
// }

// resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
//   name: 'script-identity'
//   location: location
// }

// @description('Assign permission for the deployment scripts user identity access to the read blobs from the storage account.')
// resource dataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   scope: storageAccount
//   name: guid(storageBlobDataReaderRoleDef.id, scriptIdentity.id, storageAccount.id)
//   properties: {
//     principalType: 'ServicePrincipal'
//     principalId: scriptIdentity.properties.principalId
//     roleDefinitionId: storageBlobDataReaderRoleDef.id
//   }
 
// }


// @description('Assign permission for the deployment scripts user identity access to the write files from the storage account.')
// resource dataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   scope: storageAccount
//   name: guid(storageFileDataContributorRoleDef.id, scriptIdentity.id, storageAccount.id)
//   properties: {
//     principalType: 'ServicePrincipal'
//     principalId: scriptIdentity.properties.principalId
//     roleDefinitionId: storageFileDataContributorRoleDef.id
//   }
  
// }

output fileShareFullName string = fileShare.name
output strgAccId string = storageAccount.id
