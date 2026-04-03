using '../main.bicep'

// UAT Environment Parameters
param environment = 'uat'
param location = 'eastus2'

// SQL Parameters (⚠️ CHANGE PASSWORD before deploying)
param sqlAdminUsername = 'sqladmin'
param sqlAdminPassword = 'TempPassword123!@#'  // ⚠️ MUST BE CHANGED
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

// Security - Enable for UAT testing
param enablePrivateEndpoints = true

// Tags
param tags = {}
