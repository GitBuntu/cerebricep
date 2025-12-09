using '../main.bicep'

param environment = 'uat'
param location = 'eastus2'
param workloadName = 'cerebricep'

param tags = {
  project: 'cerebricep'
  costCenter: 'testing'
}

// Moderate sizing for UAT (production-like but cost-conscious)
param functionAppSku = 'EP1'          // Elastic Premium
param cosmosDbThroughput = 1000       // Higher throughput for testing
param docIntelligenceSku = 'S0'       // Standard tier

// Enable some enterprise features for testing
param enablePrivateEndpoints = true
param enableZoneRedundancy = false
