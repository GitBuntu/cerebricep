// ============================================================================
// Main Orchestration Template
// Deploys all infrastructure for AI workloads
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

@description('Workload name used for resource naming')
@minLength(3)
@maxLength(20)
param workloadName string

@description('Tags to apply to all resources')
param tags object = {}

// Sizing parameters
@description('SKU for Function App hosting plan')
param functionAppSku string = 'Y1'

@description('Cosmos DB provisioned throughput (RU/s)')
param cosmosDbThroughput int = 400

@description('Document Intelligence SKU')
@allowed(['F0', 'S0'])
param docIntelligenceSku string = 'S0'

// Feature flags
@description('Enable private endpoints for PaaS services')
param enablePrivateEndpoints bool = false

@description('Enable zone redundancy for supported resources')
param enableZoneRedundancy bool = false

// ============================================================================
// Variables
// ============================================================================

var resourceGroupName = 'rg-${workloadName}-${environment}'
var commonTags = union(tags, {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
})

// Naming convention
var naming = {
  functionApp: 'func-${workloadName}-${environment}'
  appServicePlan: 'asp-${workloadName}-${environment}'
  storageAccount: take('st${replace(workloadName, '-', '')}${environment}', 24)
  cosmosDb: 'cosmos-${workloadName}-${environment}'
  keyVault: 'kv-${workloadName}-${environment}'
  appConfig: 'appcs-${workloadName}-${environment}'
  appInsights: 'appi-${workloadName}-${environment}'
  logAnalytics: 'log-${workloadName}-${environment}'
  docIntelligence: 'di-${workloadName}-${environment}'
  managedIdentity: 'id-${workloadName}-${environment}'
  vnet: 'vnet-${workloadName}-${environment}'
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

// Monitoring (deploy first - other resources depend on it)
module monitoring './modules/monitoring/log-analytics.bicep' = {
  scope: rg
  name: 'monitoring-${uniqueString(deployment().name)}'
  params: {
    logAnalyticsName: naming.logAnalytics
    appInsightsName: naming.appInsights
    location: location
    tags: commonTags
  }
}

// User-Assigned Managed Identity
module identity './modules/identity/user-assigned-identity.bicep' = {
  scope: rg
  name: 'identity-${uniqueString(deployment().name)}'
  params: {
    name: naming.managedIdentity
    location: location
    tags: commonTags
  }
}

// Key Vault
module keyVault './modules/config/key-vault.bicep' = {
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

// Storage Account
module storage './modules/data/storage-account.bicep' = {
  scope: rg
  name: 'storage-${uniqueString(deployment().name)}'
  params: {
    name: naming.storageAccount
    location: location
    tags: commonTags
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// Cosmos DB
module cosmosDb './modules/data/cosmos-db.bicep' = {
  scope: rg
  name: 'cosmosdb-${uniqueString(deployment().name)}'
  params: {
    name: naming.cosmosDb
    location: location
    tags: commonTags
    throughput: cosmosDbThroughput
    managedIdentityPrincipalId: identity.outputs.principalId
    enableZoneRedundancy: enableZoneRedundancy
  }
}

// App Configuration (Feature Flags)
module appConfig './modules/config/app-configuration.bicep' = {
  scope: rg
  name: 'appconfig-${uniqueString(deployment().name)}'
  params: {
    name: naming.appConfig
    location: location
    tags: commonTags
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// Document Intelligence
module docIntelligence './modules/ai/document-intelligence.bicep' = {
  scope: rg
  name: 'docintelligence-${uniqueString(deployment().name)}'
  params: {
    name: naming.docIntelligence
    location: location
    tags: commonTags
    sku: docIntelligenceSku
    managedIdentityId: identity.outputs.id
  }
}

// Function App
module functionApp './modules/compute/function-app.bicep' = {
  scope: rg
  name: 'functionapp-${uniqueString(deployment().name)}'
  params: {
    functionAppName: naming.functionApp
    appServicePlanName: naming.appServicePlan
    location: location
    tags: commonTags
    sku: functionAppSku
    managedIdentityId: identity.outputs.id
    storageAccountName: storage.outputs.name
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    appConfigEndpoint: appConfig.outputs.endpoint
    keyVaultUri: keyVault.outputs.uri
  }
}

// ============================================================================
// Outputs
// ============================================================================

output resourceGroupName string = rg.name
output functionAppName string = functionApp.outputs.name
output functionAppHostname string = functionApp.outputs.hostname
output keyVaultUri string = keyVault.outputs.uri
output cosmosDbEndpoint string = cosmosDb.outputs.endpoint
output appConfigEndpoint string = appConfig.outputs.endpoint
output docIntelligenceEndpoint string = docIntelligence.outputs.endpoint
