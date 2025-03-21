targetScope = 'resourceGroup'

@minLength(5)
@maxLength(64)
param frontDoorProfileName string

@description('Application name')
param applicationName string

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Web app to confire Front Door for')
param webAppName string

@secure()
param secondaryWebAppHostname string


var frontDoorEndpointName = applicationName
var frontDoorOriginGroupName = '${applicationName}-OriginGroup'
var frontDoorOriginName = '${applicationName}-Origin'
var frontDoorRouteName = '${applicationName}-Route'

resource frontDoorProfile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 2
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 120
    }
  }
}

resource existingWebApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: webAppName
}



resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  name: frontDoorOriginName
  parent: frontDoorOriginGroup
  properties: {
    hostName: existingWebApp.properties.defaultHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: existingWebApp.properties.defaultHostName
    priority: 1
    weight: 1000
  }
}

resource frontDoorOriginSecondary 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  name: '${frontDoorOriginName}-sec'
  parent: frontDoorOriginGroup
  properties: {
    hostName: secondaryWebAppHostname
    httpPort: 80
    httpsPort: 443
    originHostHeader: secondaryWebAppHostname
    priority: 5
    weight: 1
    enabledState: 'Disabled'
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin
    frontDoorOriginSecondary
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    cacheConfiguration: {
      compressionSettings: {
        isCompressionEnabled: false
        contentTypesToCompress: [
          'application/eot'
          'application/font'
          'application/font-sfnt'
          'application/javascript'
          'application/json'
          'application/opentype'
          'application/otf'
          'application/pkcs7-mime'
          'application/truetype'
          'application/ttf'
          'application/vnd.ms-fontobject'
          'application/xhtml+xml'
          'application/xml'
          'application/xml+rss'
          'application/x-font-opentype'
          'application/x-font-truetype'
          'application/x-font-ttf'
          'application/x-httpd-cgi'
          'application/x-javascript'
          'application/x-mpegurl'
          'application/x-opentype'
          'application/x-otf'
          'application/x-perl'
          'application/x-ttf'
          'font/eot'
          'font/ttf'
          'font/otf'
          'font/opentype'
          'image/svg+xml'
          'text/css'
          'text/csv'
          'text/html'
          'text/javascript'
          'text/js'
          'text/plain'
          'text/richtext'
          'text/tab-separated-values'
          'text/xml'
          'text/x-script'
          'text/x-component'
          'text/x-java-source'
        ]
      }
      queryStringCachingBehavior: 'UseQueryString'
    }
    ruleSets: [
      {
        id: ruleSets.id
      }
    ]
    enabledState: 'Enabled'
  }
}

resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontDoorProfile
  name: 'FrontDoorDiagnostics'
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
        category: 'FrontdoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontdoorWebApplicationFirewallLog'
        enabled: true
      }
      {
        category: 'FrontdoorHealthProbeLog'
        enabled: true
      }
    ]
  }
}




resource ruleSets 'Microsoft.Cdn/profiles/ruleSets@2024-02-01' = {
  parent: frontDoorProfile
  name: 'cache'
}

resource cachePostsRule 'Microsoft.Cdn/profiles/ruleSets/rules@2024-02-01' = {
parent: ruleSets
name: 'cachePosts'
  properties: {
    order: 100
    conditions: [
      {
        name: 'UrlPath'
        parameters: {
          typeName: 'DeliveryRuleUrlPathMatchConditionParameters'
          operator: 'Wildcard'
          negateCondition: false
          matchValues: [
            '/*/'
          ]
          transforms: []
        }
      }
    ]
    actions: [
      {
        name: 'RouteConfigurationOverride'
        parameters: {
          typeName: 'DeliveryRuleRouteConfigurationOverrideActionParameters'
          cacheConfiguration: {
            isCompressionEnabled: 'Disabled'
            queryStringCachingBehavior: 'IgnoreQueryString'
            cacheBehavior: 'OverrideAlways'
            cacheDuration: '01:00:00'
          }
          originGroupOverride: {
            originGroup: {
              id: frontDoorOriginGroup.id
            }
            forwardingProtocol: 'MatchRequest'
          }
        }
      }
    ]
    matchProcessingBehavior: 'Continue'
  }
  dependsOn: [
    frontDoorOrigin
    frontDoorOriginSecondary
  ]
}

resource excludeCacheRule 'Microsoft.Cdn/profiles/ruleSets/rules@2024-02-01'={
parent: ruleSets
name: 'excludeCache'
  properties: {
    order: 200
    conditions: [
      {
        name: 'UrlPath'
        parameters: {
          typeName: 'DeliveryRuleUrlPathMatchConditionParameters'
          operator: 'BeginsWith'
          negateCondition: false
          matchValues: [
            '/ghost/*'
          ]
          transforms: []
        }
      }
    ]
    actions: [
      {
        name: 'RouteConfigurationOverride'
        parameters: {
          typeName: 'DeliveryRuleRouteConfigurationOverrideActionParameters'
          originGroupOverride: {
            originGroup: {
              id: frontDoorOriginGroup.id
            }
            forwardingProtocol: 'MatchRequest'
          }
        }
      }
    ]
    matchProcessingBehavior: 'Continue'
  }
  dependsOn: [
    frontDoorOrigin
  ]
}



output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
output id string = frontDoorProfile.properties.frontDoorId
