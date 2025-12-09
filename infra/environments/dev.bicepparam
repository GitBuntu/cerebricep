using '../main.bicep'

param environment = 'dev'
param location = 'eastus2'
param workloadName = 'cerebricep'

param tags = {
  project: 'cerebricep'
  costCenter: 'development'
}

// Cost-optimized sizing for dev
param functionAppSku = 'Y1'           // Consumption plan
param cosmosDbThroughput = 400        // Minimum RU/s
param docIntelligenceSku = 'F0'       // Free tier

// Dev doesn't need enterprise features
param enablePrivateEndpoints = false
param enableZoneRedundancy = false
