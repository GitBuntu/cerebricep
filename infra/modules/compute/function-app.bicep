// ============================================================================
// Function App Module
// ============================================================================

@description('Name of the Function App')
param functionAppName string

@description('Name of the App Service Plan')
param appServicePlanName string

@description('Location for resources')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

@description('SKU for the App Service Plan')
@allowed(['Y1', 'EP1', 'EP2', 'EP3', 'Flex'])
param sku string = 'Y1'

@description('User-assigned managed identity resource ID')
param managedIdentityId string

@description('User-assigned managed identity client ID')
param managedIdentityClientId string

@description('Storage account name for Function App')
param storageAccountName string

@description('Storage account resource ID for Function App')
param storageAccountId string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('App Configuration endpoint')
param appConfigEndpoint string

@description('Key Vault URI')
param keyVaultUri string

@description('Function App runtime')
@allowed(['dotnet-isolated', 'node', 'python', 'java'])
param runtime string = 'dotnet-isolated'

@description('Runtime version')
param runtimeVersion string = '9.0'

// Determine plan kind and tier based on SKU
var isConsumption = sku == 'Y1'
var isFlex = sku == 'Flex'
var planKind = isConsumption ? 'functionapp' : 'elastic'
var skuTier = isConsumption ? 'Dynamic' : (isFlex ? 'FlexConsumption' : 'ElasticPremium')
var skuName = isFlex ? 'FC1' : sku

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: planKind
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    reserved: true // Linux
    maximumElasticWorkerCount: isConsumption ? null : 20
  }
}

// Common app settings (excluding runtime-specific ones that vary by plan)
var baseAppSettings = [
  {
    name: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccountId, '2022-05-01').keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
  {
    name: 'AzureWebJobsStorage'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccountId, '2022-05-01').keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: '~4'
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsightsConnectionString
  }
  {
    name: 'APP_CONFIGURATION_ENDPOINT'
    value: appConfigEndpoint
  }
  {
    name: 'KEY_VAULT_URI'
    value: keyVaultUri
  }
  {
    name: 'AZURE_CLIENT_ID'
    value: managedIdentityClientId
  }
]

// For standard plans, add FUNCTIONS_WORKER_RUNTIME
var appSettingsStandard = concat(baseAppSettings, [
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: runtime
  }
])

// For Flex, omit FUNCTIONS_WORKER_RUNTIME (it's specified in functionAppConfig.runtime)
var appSettingsFlex = baseAppSettings

// SiteConfig for Flex (no linuxFxVersion, no FUNCTIONS_WORKER_RUNTIME)
var siteConfigFlex = {
  ftpsState: 'Disabled'
  minTlsVersion: '1.2'
  http20Enabled: true
  cors: {
    allowedOrigins: [
      'https://portal.azure.com'
    ]
  }
  appSettings: appSettingsFlex
}

// SiteConfig for non-Flex (includes linuxFxVersion and FUNCTIONS_WORKER_RUNTIME)
var siteConfigStandard = {
  linuxFxVersion: '${toUpper(runtime)}|${runtimeVersion}'
  ftpsState: 'Disabled'
  minTlsVersion: '1.2'
  http20Enabled: true
  cors: {
    allowedOrigins: [
      'https://portal.azure.com'
    ]
  }
  appSettings: appSettingsStandard
}

var siteConfig = isFlex ? siteConfigFlex : siteConfigStandard

// Base properties for Function App
var functionAppBaseProperties = {
  serverFarmId: appServicePlan.id
  httpsOnly: true
  publicNetworkAccess: 'Enabled'
  clientAffinityEnabled: false
  siteConfig: siteConfig
}

// Flex-specific properties
var functionAppFlexConfig = {
  functionAppConfig: {
    deployment: {
      storage: {
        type: 'blobContainer'
        value: 'https://${storageAccountName}.blob.${environment().suffixes.storage}/'
        authentication: {
          type: 'StorageAccountConnectionString'
          storageAccountConnectionStringName: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
        }
      }
    }
    scaleAndConcurrency: {
      maximumInstanceCount: 100
      instanceMemoryMB: 2048
    }
    runtime: {
      name: runtime
      version: runtimeVersion
    }
  }
}

// Merge Flex config into base properties if needed
var functionAppProperties = isFlex ? union(functionAppBaseProperties, functionAppFlexConfig) : functionAppBaseProperties

// Function App
resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: functionAppProperties
}

// Disable basic publishing credentials (SCM)
resource basicPublishingCredentialsPolicySCM 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-11-01' = {
  parent: functionApp
  name: 'scm'
  properties: {
    allow: false
  }
}

// Disable basic publishing credentials (FTP)
resource basicPublishingCredentialsPolicyFTP 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-11-01' = {
  parent: functionApp
  name: 'ftp'
  properties: {
    allow: false
  }
}

// Outputs
output id string = functionApp.id
output name string = functionApp.name
output hostname string = functionApp.properties.defaultHostName
