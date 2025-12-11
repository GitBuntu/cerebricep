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
@allowed(['Y1', 'EP1', 'EP2', 'EP3'])
param sku string = 'Y1'

@description('User-assigned managed identity resource ID')
param managedIdentityId string

@description('User-assigned managed identity client ID')
param managedIdentityClientId string

@description('Storage account name for Function App')
param storageAccountName string

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
param runtimeVersion string = '8.0'

// Determine plan kind based on SKU
var isConsumption = sku == 'Y1'
var planKind = isConsumption ? 'functionapp' : 'elastic'
var skuTier = isConsumption ? 'Dynamic' : 'ElasticPremium'

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: planKind
  sku: {
    name: sku
    tier: skuTier
  }
  properties: {
    reserved: true // Linux
    maximumElasticWorkerCount: isConsumption ? null : 20
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
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
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      linuxFxVersion: '${toUpper(runtime)}|${runtimeVersion}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: managedIdentityClientId
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime
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
    }
  }
}

// Outputs
output id string = functionApp.id
output name string = functionApp.name
output hostname string = functionApp.properties.defaultHostName
