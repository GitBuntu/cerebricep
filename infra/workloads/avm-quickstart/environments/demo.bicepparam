using '../main.bicep'

// Azure region for deployment
param location = 'eastus'

// Environment name
param environment = 'dev'

// Key Vault name - must be globally unique
// Replace with your own unique name (3-24 characters, alphanumeric only)
param keyVaultName = 'kv-avm-quickstart-demo'

// For development: disable purge protection to allow easier deletion/recreation
// For production: set to true for additional protection against accidental deletion
param enablePurgeProtection = false

// Resource tags
param tags = {
  environment: 'dev'
  workload: 'avm-quickstart'
  source: 'cerebricep'
  managedBy: 'infrastructure-team'
  demo: 'true'
}
