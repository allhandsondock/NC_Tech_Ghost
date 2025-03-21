targetScope = 'resourceGroup'

@minLength(3)
@maxLength(63)
param mySQLServerName string

@allowed([
  'Standard_B1ms'
  'Standard_B2ms'
  'Standard_D2ads_v5'
])
param mySQLServerSku string

@description('Database administrator login name')
@minLength(1)
param administratorLogin string

@secure()
param sourceServerId string

@description('Database administrator password')
@secure()
param administratorPassword string

@description('Location to deploy the resources')
param location string

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string



resource mySQLServer 'Microsoft.DBforMySQL/flexibleServers@2024-10-01-preview' = {
  name: mySQLServerName
  location: location
  sku: {
    name: mySQLServerSku
    tier: 'GeneralPurpose'
  }
  properties: {
    createMode: 'Replica'
    version: '8.0.21'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    replicationRole: 'Replica'
    sourceServerResourceId: sourceServerId
    network: {
      publicNetworkAccess: 'Disabled'
    }
  }
}

resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource mySQLServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mySQLServer
  name: 'MySQLServerDiagnostics'
  properties: {
    workspaceId: existingWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'MySqlSlowLogs'
        enabled: true
      }
      {
        category: 'MySqlAuditLogs'
        enabled: true
      }
    ]
  }
}

output mysqlId string = mySQLServer.id
