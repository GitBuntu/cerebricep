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

@description('Region name for resource naming (e.g., eastus, westus2)')
param regionName string = 'eastus'

@description('Workload name used for resource naming')
@minLength(3)
@maxLength(20)
param workloadName string

@description('Tags to apply to all resources')
param tags object = {}

// Sizing parameters
@description('Cosmos DB with MongoDB API provisioned throughput (RU/s) - set to 0 for serverless')
param cosmosDbThroughput int = 400

@description('MongoDB API server version')
@allowed(['3.6', '4.0', '4.2', '5.0'])
param mongoServerVersion string = '4.2'

// Feature flags
@description('Enable zone redundancy for supported resources')
param enableZoneRedundancy bool = false

// ============================================================================
// Variables
// ============================================================================

var resourceGroupName = 'rg-${workloadName}-${environment}'
var deploymentSuffix = environment == 'dev' ? take(uniqueString(deployment().name), 5) : '001'
var commonTags = union(tags, {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
})

// Naming convention (follows Azure Cloud Adoption Framework + Azure Resource Namer)
// Pattern: <type>-<workload>-<environment>-<region>-<instance> (region omitted for global resources)
var naming = {
  functionApp: 'func-${workloadName}-${environment}-${regionName}-${deploymentSuffix}'
  appServicePlan: 'asp-${workloadName}-${environment}-${regionName}-${deploymentSuffix}'
  storageAccount: take('st${replace(workloadName, '-', '')}${environment}${replace(regionName, '-', '')}${deploymentSuffix}', 24)
  cosmosDb: 'cosmos-${workloadName}-${environment}-${regionName}-${deploymentSuffix}'
  keyVault: 'kv-${workloadName}-${environment}-${deploymentSuffix}'
  appConfig: 'appcs-${workloadName}-${environment}-${regionName}-${deploymentSuffix}'
  appInsights: 'appi-${workloadName}-${environment}-${regionName}-${deploymentSuffix}'
  logAnalytics: 'log-${workloadName}-${environment}-${regionName}-${deploymentSuffix}'
  docIntelligence: 'di-${workloadName}-${environment}-${regionName}-${deploymentSuffix}'
  managedIdentity: 'id-${workloadName}-${environment}-${regionName}-${deploymentSuffix}'
  vnet: 'vnet-${workloadName}-${environment}-${regionName}-${deploymentSuffix}'
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

// Reference existing resources (deployed separately)
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: naming.managedIdentity
  scope: rg
}

// Monitoring (deploy first - other resources depend on it)
// module monitoring './modules/monitoring/log-analytics.bicep' = {
//   scope: rg
//   name: 'monitoring-${uniqueString(deployment().name)}'
//   params: {
//     logAnalyticsName: naming.logAnalytics
//     appInsightsName: naming.appInsights
//     location: location
//     tags: commonTags
//   }
// }

// User-Assigned Managed Identity
// module identity './modules/identity/user-assigned-identity.bicep' = {
//   scope: rg
//   name: 'identity-${uniqueString(deployment().name)}'
//   params: {
//     name: naming.managedIdentity
//     location: location
//     tags: commonTags
//   }
// }

// Key Vault
// module keyVault './modules/config/key-vault.bicep' = {
//   scope: rg
//   name: 'keyvault-${uniqueString(deployment().name)}'
//   params: {
//     name: naming.keyVault
//     location: location
//     tags: commonTags
//     managedIdentityPrincipalId: identity.outputs.principalId
//     enablePrivateEndpoint: enablePrivateEndpoints
//   }
// }

// Storage Account
// module storage './modules/data/storage-account.bicep' = {
//   scope: rg
//   name: 'storage-${uniqueString(deployment().name)}'
//   params: {
//     name: naming.storageAccount
//     location: location
//     tags: commonTags
//     managedIdentityPrincipalId: identity.outputs.principalId
//   }
// }

// Cosmos DB with MongoDB API
module cosmosDb './modules/data/cosmos-db.bicep' = {
  scope: rg
  name: 'cosmosdb-${uniqueString(deployment().name)}'
  params: {
    name: naming.cosmosDb
    location: location
    tags: commonTags
    throughput: cosmosDbThroughput
    managedIdentityPrincipalId: managedIdentity.properties.principalId
    enableZoneRedundancy: enableZoneRedundancy
    mongoServerVersion: mongoServerVersion
  }
}

// App Configuration (Feature Flags)
// module appConfig './modules/config/app-configuration.bicep' = {
//   scope: rg
//   name: 'appconfig-${uniqueString(deployment().name)}'
//   params: {
//     name: naming.appConfig
//     location: location
//     tags: commonTags
//     managedIdentityPrincipalId: identity.outputs.principalId
//   }
// }

// Document Intelligence - Using existing free tier resource
// module docIntelligence './modules/ai/document-intelligence.bicep' = {
//   scope: rg
//   name: 'docintelligence-${uniqueString(deployment().name)}'
//   params: {
//     name: naming.docIntelligence
//     location: location
//     tags: commonTags
//     sku: docIntelligenceSku
//     managedIdentityId: identity.outputs.id
//   }
// }

// Function App
// module functionApp './modules/compute/function-app.bicep' = {
//   scope: rg
//   name: 'functionapp-${uniqueString(deployment().name)}'
//   params: {
//     functionAppName: naming.functionApp
//     appServicePlanName: naming.appServicePlan
//     location: location
//     tags: commonTags
//     sku: functionAppSku
//     managedIdentityId: identity.outputs.id
//     managedIdentityClientId: identity.outputs.clientId
//     storageAccountName: storage.outputs.name
//     storageAccountId: storage.outputs.id
//     appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
//     appConfigEndpoint: appConfig.outputs.endpoint
//     keyVaultUri: keyVault.outputs.uri
//   }
// }

// ============================================================================
// Outputs
// ============================================================================

output resourceGroupName string = rg.name
output cosmosDbEndpoint string = cosmosDb.outputs.endpoint
output cosmosDbName string = cosmosDb.outputs.name
output cosmosDbDatabaseName string = cosmosDb.outputs.databaseName
output cosmosDbMongoVersion string = cosmosDb.outputs.mongoServerVersion
