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
param functionAppSku = 'Flex'         // Flex Consumption plan (scales to 1000, no regional quota issues)
param cosmosDbThroughput = 400        // Minimum RU/s for containers

// Dev doesn't need enterprise features
param enablePrivateEndpoints = false
param enableZoneRedundancy = false
