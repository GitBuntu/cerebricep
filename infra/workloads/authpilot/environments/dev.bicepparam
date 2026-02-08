using '../main.bicep'

// ============================================================================
// AuthPilot Development Environment Parameters
// ============================================================================

// Environment Configuration
param environment = 'dev'
param location = 'eastus'
param tags = {
  project: 'authpilot'
  costCenter: 'engineering'
}

// DocumentDB Configuration (MongoDB)
param documentDbAdminUsername = 'dbadmin'
param documentDbAdminPassword = readEnvironmentVariable('DOCUMENTDB_ADMIN_PASSWORD', '')
param documentDbServerVersion = '8.0'
param documentDbComputeTier = 'M10'
param documentDbStorageSizeGb = 32
param documentDbShardCount = 1
param documentDbEnableHighAvailability = false
param documentDbPublicNetworkAccess = true
param documentDbFirewallRules = []

// Function App Configuration
param appServicePlanSku = 'Y1' // Consumption plan for dev
param functionAppRuntime = 'dotnet-isolated'
param functionAppRuntimeVersion = '9.0'
param enableDeploymentSlots = false
param enablePrivateEndpoints = false

// Monitoring Configuration
param logAnalyticsRetentionInDays = 30
param appInsightsRetentionInDays = 90
param enableSmartDetection = true

// Storage Configuration
param storageAccountSku = 'Standard_LRS'
