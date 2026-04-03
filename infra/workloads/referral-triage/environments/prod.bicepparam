using '../main.bicep'

// Production Environment Parameters
param environment = 'prod'
param location = 'eastus2'

// SQL Parameters (⚠️ CHANGE PASSWORD before deploying)
param sqlAdminUsername = 'sqladmin'
param sqlAdminPassword = 'TempPassword123!@#'  // ⚠️ MUST BE CHANGED
param sqlDatabaseSku = 'Premium_P2'

// Function App - Use Premium Plan for production
param appServicePlanSku = 'P1V2'
param functionAppRuntime = 'dotnet-isolated'
param functionAppRuntimeVersion = '9.0'

// Monitoring - Full 30 day retention for compliance
param logAnalyticsRetentionInDays = 30
param appInsightsRetentionInDays = 90

// Storage
param storageAccountSku = 'Standard_LRS'

// AI Services
param documentIntelligenceSkuName = 'S0'

// Security - Enable for production
param enablePrivateEndpoints = true

// Tags
param tags = {}
