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
param functionAppSku = 'Y1'           // Consumption plan - free tier (~1M executions/month)
param cosmosDbThroughput = 100        // Free tier: 100 RU/s + 25 GB/month
param docIntelligenceSku = 'F0'       // Free tier: 500 transactions/month

// Dev doesn't need enterprise features
param enablePrivateEndpoints = false
param enableZoneRedundancy = false
