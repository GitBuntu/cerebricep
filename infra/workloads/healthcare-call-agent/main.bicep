// =====================================================================
// Healthcare Call Agent MVP - Main Workload Template
// =====================================================================
// Purpose: Orchestrate deployment of healthcare call agent application
//          across resource groups using cross-RG referencing pattern
// Scope: Subscription-level (creates resource group + resources)
// 
// Resources:
// - Resource Group: rg-healthcare-call-agent-{environment}
// - Storage Account: for Functions runtime
// - SQL Server & Database: for call data persistence
// - User-Assigned Managed Identity: for RBAC
// - App Service Plan: Consumption tier for cost optimization
// - Function App: main application runtime
// 
// Cross-RG References:
// - Azure Communication Services (ACS) from rg-vm-prod-canadacentral-001
// - Azure AI Services from rg-vm-prod-canadacentral-001
//
// Dependencies:
// - Modules: storage-account, sql-database, user-assigned-identity,
//   app-service-plan, function-app
// =====================================================================

// ==== Bicep Language & Metadata ====
targetScope = 'subscription'

metadata name = 'Healthcare Call Agent MVP'
metadata description = 'Cross-RG infrastructure deployment for healthcare call agent'
metadata version = '1.0.0'

// =====================================================================
// Parameters
// =====================================================================

@minLength(1)
@maxLength(5)
@description('Workload environment (dev, uat, prod)')
@allowed([ 'dev', 'uat', 'prod' ])
param environment string

@description('Azure region for resource deployment')
param location string = 'westus'

@description('Resource Group Name')
param resourceGroupName string = 'rg-healthcare-call-agent-${environment}'

// Shared resources configuration
@description('Shared resource group name (contains ACS, AI Services)')
param sharedResourceGroupName string = 'rg-vm-prod-canadacentral-001'

@description('Shared resource group subscription ID')
param sharedResourceGroupSubscriptionId string

@description('Name of shared Azure Communication Services resource')
param sharedAcsResourceName string

@description('Name of shared Azure AI Services (Cognitive Services) resource')
param sharedAiServicesResourceName string

// SQL Configuration
@description('SQL Server admin username')
@minLength(1)
@maxLength(128)
param sqlAdminUsername string = 'sqladmin'

@secure()
@description('SQL Server admin password')
param sqlAdminPassword string

// Function App Configuration
@description('Function App runtime environment')
@allowed(['dotnet-isolated', 'node', 'python', 'java'])
param functionAppRuntime string = 'dotnet-isolated'

@description('Function App runtime version')
param functionAppRuntimeVersion string = '9.0'

@description('App Service Plan SKU (Y1=Consumption for MVP)')
@allowed(['Y1', 'EP1', 'EP2', 'EP3', 'P1V2', 'P2V2', 'P3V2', 'Flex'])
param appServicePlanSku string = 'Y1'

// Tags
@description('Tags for all resources')
param tags object = {
  workload: 'healthcare-call-agent'
  environment: environment
  managedBy: 'IaC'
  createdDate: utcNow('yyyy-MM-dd')
}

// =====================================================================
// Variables
// =====================================================================

// Resource naming (following cerebricep conventions)
var storageAccountName = 'sthc${uniqueString(subscription().subscriptionId)}' // 24-char max: sthc + 13-char hash = 17 chars
var sqlServerName = 'sql-healthcare-call-agent-${environment}'
var sqlDatabaseName = 'db-calls-${environment}'
var msiName = 'id-healthcare-call-agent-${environment}'
var appServicePlanName = 'asp-healthcare-call-agent-${environment}'
var functionAppName = 'func-healthcare-call-agent-${environment}'

// Shared resource references
var sharedRgSubscriptionId = sharedResourceGroupSubscriptionId
var sharedRgName = sharedResourceGroupName

// =====================================================================
// Cross-RG Resource Queries
// =====================================================================

@description('Reference to shared ACS resource in different RG')
resource sharedAcs 'Microsoft.Communication/communicationServices@2025-05-01' existing = {
  name: sharedAcsResourceName
  scope: resourceGroup(sharedRgSubscriptionId, sharedRgName)
}

@description('Reference to shared AI Services (Cognitive Services) resource in different RG')
resource sharedAiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: sharedAiServicesResourceName
  scope: resourceGroup(sharedRgSubscriptionId, sharedRgName)
}

// Extract properties from shared resources
var acsConnectionString = sharedAcs.listKeys().primaryConnectionString
var acsResourceId = sharedAcs.id
var aiServicesKey = sharedAiServices.listKeys().key1
var aiServicesEndpoint = sharedAiServices.properties.endpoint

// Error checking: Validate shared resources are accessible
var sharedResourcesAccessible = !empty(acsConnectionString) && !empty(aiServicesKey)

// =====================================================================
// Resource Group
// =====================================================================

@description('Workload resource group')
resource rg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// =====================================================================
// Module Deployments (in dependency order)
// =====================================================================

@description('User-Assigned Managed Identity for RBAC chain')
module identityModule '../../modules/identity/user-assigned-identity.bicep' = {
  scope: rg
  name: 'identity-${uniqueString(deployment().name)}'
  params: {
    name: msiName
    location: location
    tags: tags
  }
}

@description('Storage Account for Function App runtime and artifact storage')
module storageModule '../../modules/data/storage-account.bicep' = {
  scope: rg
  name: 'storage-${uniqueString(deployment().name)}'
  params: {
    name: storageAccountName
    location: location
    tags: tags
    managedIdentityPrincipalId: identityModule.outputs.principalId
    sku: 'Standard_LRS'
    accessTier: 'Hot'
    enableVersioning: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: false
  }
}

@description('SQL Server and Database for call data persistence')
module sqlDbModule '../../modules/data/sql-database.bicep' = {
  scope: rg
  name: 'sqldb-${uniqueString(deployment().name)}'
  params: {
    serverName: sqlServerName
    databaseName: sqlDatabaseName
    location: location
    tags: tags
    adminUsername: sqlAdminUsername
    adminPassword: sqlAdminPassword
    sku: 'Basic'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeGb: 2
    allowAzureServicesAccess: true
  }
}

@description('App Service Plan for Function App (Consumption/Y1 for MVP)')
module appServicePlanModule '../../modules/compute/app-service-plan.bicep' = {
  scope: rg
  name: 'aspplan-${uniqueString(deployment().name)}'
  params: {
    name: appServicePlanName
    location: location
    tags: tags
    sku: appServicePlanSku
    maximumElasticWorkerCount: 20
    enableZoneRedundancy: false
  }
}

@description('Function App with cross-RG resource configuration injected')
module functionAppModule '../../modules/compute/function-app.bicep' = {
  scope: rg
  name: 'funcapp-${uniqueString(deployment().name)}'
  params: {
    functionAppName: functionAppName
    sku: appServicePlanSku
    appServicePlanId: appServicePlanModule.outputs.id
    location: location
    tags: tags
    managedIdentityId: identityModule.outputs.id
    managedIdentityClientId: identityModule.outputs.clientId
    storageAccountName: storageModule.outputs.name
    storageAccountId: storageModule.outputs.id
    appInsightsConnectionString: '' // TODO: Add Application Insights in Phase 2
    appConfigEndpoint: '' // TODO: Add App Configuration in Phase 2
    keyVaultUri: '' // TODO: Add Key Vault in Phase 2
    runtime: functionAppRuntime
    runtimeVersion: functionAppRuntimeVersion
    enableDeploymentSlots: false
    enablePrivateEndpoint: false
    // Additional app settings with cross-RG resource configuration
    additionalAppSettings: [
      {
        name: 'ACS_CONNECTION_STRING'
        value: acsConnectionString
      }
      {
        name: 'ACS_RESOURCE_ID'
        value: acsResourceId
      }
      {
        name: 'AI_SERVICES_ENDPOINT'
        value: aiServicesEndpoint
      }
      {
        name: 'AI_SERVICES_KEY'
        value: aiServicesKey
      }
      {
        name: 'SQL_CONNECTION_STRING'
        value: 'Server=tcp:${sqlDbModule.outputs.serverFqdn},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID=${sqlAdminUsername};Password={PASSWORD};Encrypt=true;Connection Timeout=30;'
      }
      {
        name: 'ENVIRONMENT'
        value: environment
      }
    ]
  }
  // Bicep automatically infers module dependencies from parameter references
}

// =====================================================================
// Outputs
// =====================================================================

@description('Resource Group ID')
output resourceGroupId string = rg.id

@description('Resource Group Name')
output resourceGroupName string = rg.name

// Identity Outputs
@description('User-Assigned Managed Identity ID')
output managedIdentityId string = identityModule.outputs.id

@description('User-Assigned Managed Identity Principal ID (for RBAC)')
output managedIdentityPrincipalId string = identityModule.outputs.principalId

@description('User-Assigned Managed Identity Client ID')
output managedIdentityClientId string = identityModule.outputs.clientId

// Storage Outputs
@description('Storage Account ID')
output storageAccountId string = storageModule.outputs.id

@description('Storage Account Name')
output storageAccountName string = storageModule.outputs.name

@description('Storage Account Blob Endpoint')
output storageBlobEndpoint string = storageModule.outputs.blobEndpoint

// SQL Outputs
@description('SQL Server FQDN')
output sqlServerFqdn string = sqlDbModule.outputs.serverFqdn

@description('SQL Server ID')
output sqlServerId string = sqlDbModule.outputs.serverId

@description('SQL Database ID')
output sqlDatabaseId string = sqlDbModule.outputs.databaseId

@description('SQL Database Name')
output sqlDatabaseName string = sqlDbModule.outputs.databaseName

// Function App Outputs
@description('Function App ID')
output functionAppId string = functionAppModule.outputs.id

@description('Function App Name')
output functionAppName string = functionAppModule.outputs.name

// Cross-RG Configuration Status
@description('Shared ACS resource ID (from cross-RG query)')
output sharedAcsResourceId string = acsResourceId

@description('Cross-RG resources accessible (validation check)')
output sharedResourcesAccessible bool = sharedResourcesAccessible

// Deployment Metadata
@description('Environment')
output environment string = environment

@description('Region')
output region string = location
