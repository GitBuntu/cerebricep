using '../main.bicep'

// Development Environment Parameters
param environment = 'dev'
param location = 'eastus2'

// SQL Parameters (⚠️ CHANGE PASSWORD before deploying)
param sqlAdminUsername = 'sqladmin'
param sqlAdminPassword = 'TempPassword123!@#'  // ⚠️ MUST BE CHANGED
param sqlDatabaseSku = 'Standard_S1'

// Function App - Use Consumption for cost optimization in dev
param appServicePlanSku = 'Y1'
param functionAppRuntime = 'dotnet-isolated'
param functionAppRuntimeVersion = '9.0'

// Monitoring - Lower retention for dev/cost savings
param logAnalyticsRetentionInDays = 30
param appInsightsRetentionInDays = 30

// Storage
param storageAccountSku = 'Standard_LRS'

// AI Services
param documentIntelligenceSkuName = 'S0'

// Optional Features
param enablePrivateEndpoints = false

// Tags
param tags = {}
