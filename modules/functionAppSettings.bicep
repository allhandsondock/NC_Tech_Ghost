param fnAppName string
param aiKey string
param storageAccountName string
param isPrimary bool
param ghostUrl string
param ghostAPISecretUri string

resource fnappSetting 'Microsoft.Web/sites/config@2021-01-15' = if(isPrimary) {
  name: '${fnAppName}/appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: aiKey
    AzureWebJobsStorage__accountname: storageAccountName
    GHOST_URL: ghostUrl
    GHOST_ADMIN_API_KEY: '@Microsoft.KeyVault(SecretUri=${ghostAPISecretUri})'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'node'
    WEBSITE_NODE_DEFAULT_VERSION: '~16'
  }
}
