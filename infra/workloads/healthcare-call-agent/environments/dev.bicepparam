using '../main.bicep'

param environment = 'dev'
param location = 'westus'

// SQL Admin Credentials (for MVP - Phase 2 will use Key Vault + Managed Identity)
param sqlAdminPassword = ''  // TODO: Set locally or use Key Vault in Phase 2

// Shared resources configuration
param sharedResourceGroupSubscriptionId = ''  // TODO: Replace with your subscription ID (az account show --query id -o tsv)
param sharedResourceGroupName = 'rg-vm-prod-canadacentral-001'
param sharedAcsResourceName = 'callistra-test'
param sharedAiServicesResourceName = 'callistra-speech-services'

// SQL Configuration
param sqlAdminUsername = 'sqladmin'

// Function App Configuration
param functionAppRuntime = 'dotnet-isolated'
param functionAppRuntimeVersion = '9.0'
param appServicePlanSku = 'Flex'  // Flex consumption plan (no quota required)
