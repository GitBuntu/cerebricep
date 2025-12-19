using '../../main.bicep'

param environment = 'dev'
param location = 'eastus'
param regionName = 'eastus'
param workloadName = 'authpilot'

param tags = {
  project: 'authpilot'
  costCenter: 'development'
  application: 'fax-processing'
}

// Cost-optimized sizing for dev (free tier where possible)
param functionAppSku = 'EP1'           // Elastic Premium P1 (serverless, avoids consumption quota issues)
param cosmosDbThroughput = 400        // Minimum RU/s for containers
param docIntelligenceSku = 'S0'       // Standard tier - pay

// Dev doesn't need enterprise features
param enablePrivateEndpoints = false
param enableZoneRedundancy = false
