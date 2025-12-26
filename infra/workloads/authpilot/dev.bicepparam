using '../../main.bicep'

param environment = 'dev'
param location = 'eastus'
param workloadName = 'authpilot'

param tags = {
  project: 'authpilot'
  costCenter: 'development'
  application: 'fax-processing'
}

// DocumentDB configuration for dev
param documentDbAdminPassword = readEnvironmentVariable('DOCUMENTDB_ADMIN_PASSWORD', 'ChangeMe123!')
param documentDbComputeTier = 'M10'              // Smallest shared tier
param documentDbStorageSizeGb = 32               // Minimum storage
param documentDbEnableHighAvailability = false   // No HA for dev
