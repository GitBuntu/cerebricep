using '../main.bicep'

// UAT Environment Parameters
param environment = 'uat'
param location = 'eastus2'

// SQL Parameters
// NOTE: sqlAdminPassword must be provided at deploy-time (e.g., --parameters sqlAdminPassword=YourSecurePassword)
// DO NOT commit passwords to this file
param sqlAdminUsername = 'sqladmin'
// Password parameter intentionally omitted - provide via CLI or environment variable
param sqlDatabaseSku = 'Standard_S2'

// Function App - Use Premium Plan for consistent performance
param appServicePlanSku = 'P1V2'
param functionAppRuntime = 'dotnet-isolated'
param functionAppRuntimeVersion = '9.0'

// Monitoring - 30 day retention (minimum)
param logAnalyticsRetentionInDays = 30
param appInsightsRetentionInDays = 90

// Storage
param storageAccountSku = 'Standard_LRS'

// AI Services
param documentIntelligenceSkuName = 'S0'

// Security - Private Endpoints
// NOTE: Set to false for now because Key Vault module only disables public access but doesn't create PE.
// To enable: (1) Deploy VNet + subnet, (2) Add privateEndpointSubnetId, (3) Extend key-vault module to create PE
param enablePrivateEndpoints = false

// Networking - Private Endpoints (required if enablePrivateEndpoints = true)
// Replace with actual subnet ID from your VNet: /subscriptions/{subscriptionId}/resourceGroups/{rgName}/providers/Microsoft.Network/virtualNetworks/{vnetName}/subnets/{subnetName}
param privateEndpointSubnetId = ''

// Tags
param tags = {}
