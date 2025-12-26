using '../main.bicep'

param environment = 'prod'
param location = 'eastus2'
param workloadName = 'cerebricep'

param tags = {
  project: 'cerebricep'
  costCenter: 'production'
}

param cosmosDbThroughput = 4000
param mongoServerVersion = '4.2'
param enableZoneRedundancy = true
