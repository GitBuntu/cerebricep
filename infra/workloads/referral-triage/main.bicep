// ============================================================================
// Referral Triage Workload - Main Orchestration Template
// Deploys complete infrastructure for referral intake and triage pipeline
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

// SQL Parameters
@description('SQL Server admin username')
param sqlAdminUsername string

@description('SQL Server admin password')
@secure()
param sqlAdminPassword string

@description('SQL Database SKU')
@allowed(['Basic', 'Standard_S0', 'Standard_S1', 'Standard_S2', 'Standard_S3', 'Standard_S4', 'Premium_P1', 'Premium_P2', 'Premium_P4', 'Premium_P6'])
param sqlDatabaseSku string = 'Standard_S1'

// Function App Parameters
@description('App Service Plan SKU')
@allowed(['Y1', 'EP1', 'EP2', 'EP3', 'Flex', 'P1V2', 'P2V2', 'P3V2'])
param appServicePlanSku string = 'Y1'

@description('Function App runtime')
@allowed(['dotnet-isolated', 'node', 'python', 'java'])
param functionAppRuntime string = 'dotnet-isolated'

@description('Function App runtime version')
param functionAppRuntimeVersion string = '9.0'

// Monitoring Parameters
@description('Log Analytics retention in days')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionInDays int = 30

@description('Application Insights retention in days')
@minValue(30)
@maxValue(730)
param appInsightsRetentionInDays int = 90

// Storage Parameters
@description('Storage account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Premium_LRS'])
param storageAccountSku string = 'Standard_LRS'

// AI Services Parameters
@description('Document Intelligence SKU')
@allowed(['F0', 'S0'])
param documentIntelligenceSkuName string = 'S0'

// Optional Features
@description('Enable private endpoints for resources')
param enablePrivateEndpoints bool = false

// ============================================================================
// Variables
// ============================================================================

var workloadName = 'referral-triage'
var resourceGroupName = 'rg-${workloadName}-${environment}'
var commonTags = union(tags, {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
})

var naming = {
  identity: 'id-${workloadName}-${environment}'
  storageAccount: 'st${workloadName}${environment}'
  keyVault: 'kv-${workloadName}-${environment}'
  logAnalytics: 'log-${workloadName}-${environment}'
  appInsights: 'appi-${workloadName}-${environment}'
  appServicePlan: 'asp-${workloadName}-${environment}'
  functionApp: 'func-${workloadName}-${environment}'
  sqlServer: 'sql-${workloadName}-${environment}'
  sqlDatabase: 'ReferralTriage'
  documentIntelligence: 'docint-${workloadName}-${environment}'
  openAi: 'openai-${workloadName}-${environment}'
}

// ============================================================================
// Resource Group
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
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
  name: 'identity-${uniqueString(rg.id)}'
  params: {
    name: naming.identity
    location: location
    tags: commonTags
  }
}

// 2. Storage Account
module storageAccount '../../modules/data/storage-account.bicep' = {
  scope: rg
  name: 'storage-${uniqueString(rg.id)}'
  params: {
    name: naming.storageAccount
    location: location
    tags: commonTags
    managedIdentityPrincipalId: identity.outputs.principalId
    sku: storageAccountSku
    blobContainers: ['referrals-incoming', 'referrals-processed']
    queueNames: ['referral-dlq']
  }
}

// 3. Log Analytics Workspace
module logAnalytics '../../modules/monitoring/log-analytics.bicep' = {
  scope: rg
  name: 'loganalytics-${uniqueString(rg.id)}'
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
  name: 'appinsights-${uniqueString(rg.id)}'
  params: {
    name: naming.appInsights
    location: location
    tags: commonTags
    workspaceResourceId: logAnalytics.outputs.id
    retentionInDays: appInsightsRetentionInDays
  }
}

// 5. Key Vault
module keyVault '../../modules/config/key-vault.bicep' = {
  scope: rg
  name: 'keyvault-${uniqueString(rg.id)}'
  params: {
    name: naming.keyVault
    location: location
    tags: commonTags
    managedIdentityPrincipalId: identity.outputs.principalId
    enablePrivateEndpoint: enablePrivateEndpoints
  }
}

// 6. SQL Server and Database
module sqlDatabase '../../modules/data/sql-database.bicep' = {
  scope: rg
  name: 'sqldb-${uniqueString(rg.id)}'
  params: {
    serverName: naming.sqlServer
    databaseName: naming.sqlDatabase
    location: location
    tags: commonTags
    adminUsername: sqlAdminUsername
    adminPassword: sqlAdminPassword
    sku: sqlDatabaseSku
  }
}

// 7. Document Intelligence
module documentIntelligence '../../modules/ai/document-intelligence.bicep' = {
  scope: rg
  name: 'docint-${uniqueString(rg.id)}'
  params: {
    name: naming.documentIntelligence
    location: location
    tags: commonTags
    sku: documentIntelligenceSkuName
    managedIdentityId: identity.outputs.id
  }
}

// 8. App Service Plan
module appServicePlan '../../modules/compute/app-service-plan.bicep' = {
  scope: rg
  name: 'appserviceplan-${uniqueString(rg.id)}'
  params: {
    name: naming.appServicePlan
    location: location
    tags: commonTags
    sku: appServicePlanSku
  }
}

// 9. Function App
module functionApp '../../modules/compute/function-app.bicep' = {
  scope: rg
  name: 'functionapp-${uniqueString(rg.id)}'
  params: {
    functionAppName: naming.functionApp
    location: location
    tags: commonTags
    appServicePlanId: appServicePlan.outputs.id
    sku: appServicePlanSku
    managedIdentityId: identity.outputs.id
    managedIdentityClientId: identity.outputs.clientId
    storageAccountName: storageAccount.outputs.name
    storageAccountId: storageAccount.outputs.id
    appInsightsConnectionString: appInsights.outputs.connectionString
    appConfigEndpoint: ''
    keyVaultUri: keyVault.outputs.uri
    runtime: functionAppRuntime
    runtimeVersion: functionAppRuntimeVersion
    enablePrivateEndpoint: enablePrivateEndpoints
  }
}

// ============================================================================
// POST-DEPLOYMENT CONFIGURATION NOTES
// ============================================================================
// The following resources require post-deployment setup:
// 1. Azure OpenAI: Deploy separately with required API version and capacity
// 2. SQL Database: Create managed identity login for function app
// 3. Key Vault: Add secrets for AI services (Document Intelligence key, OpenAI key)
// 4. Role Assignments: Grant function app identity Data Reader role on SQL Database
// 5. Function Code: Deploy compiled function app code to deployment slot

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource Group Name')
output resourceGroupName string = rg.name

@description('Resource Group ID')
output resourceGroupId string = rg.id

@description('Managed Identity Resource ID')
output managedIdentityId string = identity.outputs.id

@description('Managed Identity Principal ID (for RBAC)')
output managedIdentityPrincipalId string = identity.outputs.principalId

@description('Storage Account Name')
output storageAccountName string = storageAccount.outputs.name

@description('Storage Account ID')
output storageAccountId string = storageAccount.outputs.id

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.uri

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlDatabase.outputs.serverFqdn

@description('SQL Database Name')
output sqlDatabaseName string = naming.sqlDatabase

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey

@description('Function App Name')
output functionAppName string = functionApp.outputs.name

@description('Document Intelligence Endpoint')
output documentIntelligenceEndpoint string = documentIntelligence.outputs.endpoint
