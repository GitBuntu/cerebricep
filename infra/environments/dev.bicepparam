using '../main.bicep'

param environment = 'dev'
param location = 'eastus2'
param workloadName = 'cerebricep'

param tags = {
  project: 'cerebricep'
  costCenter: 'development'
}

param cosmosDbThroughput = 400
param mongoServerVersion = '4.2'
param enableZoneRedundancy = false
