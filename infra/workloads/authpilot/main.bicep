// ============================================================================
// AuthPilot Workload - Main Orchestration Template
// Deploys complete infrastructure for fax processing application
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev, uat, prod)')
@allowed(['dev', 'uat', 'prod'])
param environment string

@description('Azure region for all resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

// DocumentDB Parameters
@description('DocumentDB admin username')
param documentDbAdminUsername string = 'dbadmin'

@description('DocumentDB admin password')
@secure()
param documentDbAdminPassword string

@description('DocumentDB server version')
@allowed(['4.2', '5.0', '6.0', '7.0', '8.0'])
param documentDbServerVersion string = '8.0'

@description('DocumentDB compute tier')
@allowed(['M10', 'M20', 'M30', 'M40', 'M50', 'M60', 'M80', 'M200', 'M250', 'M300'])
param documentDbComputeTier string = 'M10'

@description('DocumentDB storage size in GB')
@minValue(32)
@maxValue(512)
param documentDbStorageSizeGb int = 32

@description('DocumentDB shard count')
@minValue(1)
@maxValue(3)
param documentDbShardCount int = 1

@description('Enable DocumentDB high availability')
param documentDbEnableHighAvailability bool = false

@description('DocumentDB public network access')
param documentDbPublicNetworkAccess bool = true

@description('DocumentDB firewall rules')
param documentDbFirewallRules array = []

// Function App Parameters
@description('App Service Plan SKU')
@allowed(['Y1', 'EP1', 'EP2', 'EP3', 'Flex', 'P1V2', 'P2V2', 'P3V2'])
param appServicePlanSku string = 'Y1'

@description('Function App runtime')
@allowed(['dotnet-isolated', 'node', 'python', 'java'])
param functionAppRuntime string = 'dotnet-isolated'

@description('Function App runtime version')
param functionAppRuntimeVersion string = '9.0'

@description('Enable Function App deployment slots')
param enableDeploymentSlots bool = false

@description('Enable private endpoints for resources')
param enablePrivateEndpoints bool = false

// Monitoring Parameters
@description('Log Analytics retention in days')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionInDays int = 30

@description('Application Insights retention in days')
@minValue(30)
@maxValue(730)
param appInsightsRetentionInDays int = 90

@description('Enable smart detection alerts')
param enableSmartDetection bool = true

// Storage Parameters
@description('Storage account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS'])
param storageAccountSku string = 'Standard_LRS'

// ============================================================================
// Variables
// ============================================================================

var workloadName = 'authpilot'
var resourceGroupName = 'rg-${workloadName}-${environment}'
var commonTags = union(tags, {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
})

var naming = {
  identity: 'id-${workloadName}-${environment}'
  documentDb: 'mongodb-${workloadName}-${environment}'
  storageAccount: 'st${workloadName}${environment}'
  keyVault: 'kv-${workloadName}-${environment}'
  logAnalytics: 'log-${workloadName}-${environment}'
  appInsights: 'appi-${workloadName}-${environment}'
  appServicePlan: 'asp-${workloadName}-${environment}'
  functionApp: 'func-${workloadName}-${environment}'
  actionGroup: 'ag-${workloadName}-${environment}'
}

// ============================================================================
// Resource Group
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: commonTags
}

// ============================================================================
// Module Deployments
// ============================================================================

// 1. User-Assigned Managed Identity
module identity '../../modules/identity/user-assigned-identity.bicep' = {
  scope: rg
  name: 'identity-${uniqueString(deployment().name)}'
  params: {
    name: naming.identity
    location: location
    tags: commonTags
  }
}

// 2. Storage Account
module storage '../../modules/data/storage-account.bicep' = {
  scope: rg
  name: 'storage-${uniqueString(deployment().name)}'
  params: {
    name: naming.storageAccount
    location: location
    tags: commonTags
    managedIdentityPrincipalId: identity.outputs.principalId
    sku: storageAccountSku
  }
}

// 3. Log Analytics Workspace
module logAnalytics '../../modules/monitoring/log-analytics.bicep' = {
  scope: rg
  name: 'loganalytics-${uniqueString(deployment().name)}'
  params: {
    name: naming.logAnalytics
    location: location
    tags: commonTags
    retentionInDays: logAnalyticsRetentionInDays
  }
}

// 4. Application Insights
module appInsights '../../modules/monitoring/application-insights.bicep' = {
  scope: rg
  name: 'appinsights-${uniqueString(deployment().name)}'
  params: {
    name: naming.appInsights
    location: location
    tags: commonTags
    workspaceResourceId: logAnalytics.outputs.id
    retentionInDays: appInsightsRetentionInDays
    enableSmartDetection: enableSmartDetection
  }
}

// 5. Key Vault
module keyVault '../../modules/config/key-vault.bicep' = {
  scope: rg
  name: 'keyvault-${uniqueString(deployment().name)}'
  params: {
    name: naming.keyVault
    location: location
    tags: commonTags
    managedIdentityPrincipalId: identity.outputs.principalId
    enablePrivateEndpoint: enablePrivateEndpoints
  }
}

// 6. DocumentDB (MongoDB)
module documentDb '../../modules/data/documentdb.bicep' = {
  scope: rg
  name: 'documentdb-${uniqueString(deployment().name)}'
  params: {
    name: naming.documentDb
    location: location
    tags: commonTags
    adminUsername: documentDbAdminUsername
    adminPassword: documentDbAdminPassword
    serverVersion: documentDbServerVersion
    computeTier: documentDbComputeTier
    storageSizeGb: documentDbStorageSizeGb
    shardCount: documentDbShardCount
    enableHighAvailability: documentDbEnableHighAvailability
    publicNetworkAccess: documentDbPublicNetworkAccess
    firewallRules: documentDbFirewallRules
  }
}

// 7. App Service Plan
module appServicePlan '../../modules/compute/app-service-plan.bicep' = {
  scope: rg
  name: 'appserviceplan-${uniqueString(deployment().name)}'
  params: {
    name: naming.appServicePlan
    location: location
    tags: commonTags
    sku: appServicePlanSku
  }
}

// 8. Function App
module functionApp '../../modules/compute/function-app.bicep' = {
  scope: rg
  name: 'functionapp-${uniqueString(deployment().name)}'
  params: {
    functionAppName: naming.functionApp
    location: location
    tags: commonTags
    appServicePlanId: appServicePlan.outputs.id
    sku: appServicePlanSku
    managedIdentityId: identity.outputs.id
    managedIdentityClientId: identity.outputs.clientId
    storageAccountName: storage.outputs.name
    storageAccountId: storage.outputs.id
    appInsightsConnectionString: appInsights.outputs.connectionString
    appConfigEndpoint: ''
    keyVaultUri: keyVault.outputs.uri
    runtime: functionAppRuntime
    runtimeVersion: functionAppRuntimeVersion
    enableDeploymentSlots: enableDeploymentSlots
    enablePrivateEndpoint: enablePrivateEndpoints
  }
}

// 9. Action Group (for alerts)
module actionGroup '../../modules/monitoring/action-groups.bicep' = {
  scope: rg
  name: 'actiongroup-${uniqueString(deployment().name)}'
  params: {
    name: naming.actionGroup
    location: 'global'
    tags: commonTags
    shortName: 'authpilot'
    enabled: true
    emailReceivers: []
  }
}

// ============================================================================
// Outputs
// ============================================================================

output resourceGroupName string = rg.name
output resourceGroupId string = rg.id

// Identity
output identityId string = identity.outputs.id
output identityPrincipalId string = identity.outputs.principalId
output identityClientId string = identity.outputs.clientId

// Storage
output storageAccountName string = storage.outputs.name
output storageAccountId string = storage.outputs.id

// Monitoring
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
output appInsightsConnectionString string = appInsights.outputs.connectionString
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey

// Security
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri

// Database
output documentDbName string = documentDb.outputs.name
output documentDbConnectionString string = documentDb.outputs.connectionString

// Compute
output appServicePlanId string = appServicePlan.outputs.id
output functionAppName string = functionApp.outputs.name
output functionAppHostname string = functionApp.outputs.hostname

// Alerting
output actionGroupId string = actionGroup.outputs.id
