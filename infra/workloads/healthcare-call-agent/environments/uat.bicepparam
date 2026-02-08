using '../main.bicep'

param environment = 'uat'
param location = 'eastus2'

// SQL Admin Credentials (for MVP - Phase 2 will use Key Vault + Managed Identity)
param sqlAdminPassword = ''  // REQUIRED: Set before deployment (e.g., az deployment sub create --parameters @uat.bicepparam sqlAdminPassword='...')

// Shared resources configuration
param sharedResourceGroupSubscriptionId = ''  // REQUIRED: Set your subscription ID (az account show --query id -o tsv)
param sharedResourceGroupName = 'rg-vm-prod-canadacentral-001'
param sharedAcsResourceName = 'callistra-test'
param sharedAiServicesResourceName = 'callistra-speech-services'

// SQL Configuration
param sqlAdminUsername = 'sqladmin'

// Function App Configuration
param functionAppRuntime = 'dotnet-isolated'
param functionAppRuntimeVersion = '9.0'
param appServicePlanSku = 'P1V2'  // Premium v2 for UAT (mid-tier performance)
