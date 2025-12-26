using '../main.bicep'

param environment = 'uat'
param location = 'eastus2'
param workloadName = 'cerebricep'

param tags = {
  project: 'cerebricep'
  costCenter: 'testing'
}

param cosmosDbThroughput = 1000
param mongoServerVersion = '4.2'
param enableZoneRedundancy = false
