using '../main.bicep'

param environment = 'prod'
param location = 'eastus2'
param workloadName = 'cerebricep'

param tags = {
  project: 'cerebricep'
  costCenter: 'production'
}

// Production sizing (performance + reliability)
param functionAppSku = 'EP2'          // Elastic Premium (larger)
param cosmosDbThroughput = 4000       // Production throughput
param docIntelligenceSku = 'S0'       // Standard tier

// Full enterprise features
param enablePrivateEndpoints = true
param enableZoneRedundancy = true
