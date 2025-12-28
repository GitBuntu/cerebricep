// ============================================================================
// Main Orchestration Template
// Deploys Azure DocumentDB for MongoDB only
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev, uat, prod)')
@allowed(['dev', 'uat', 'prod'])
param environment string

@description('Azure region for all resources')
param location string

@description('Workload name used for resource naming')
@minLength(3)
@maxLength(20)
param workloadName string

@description('Tags to apply to all resources')
param tags object = {}

@description('DocumentDB admin password')
@secure()
param documentDbAdminPassword string

@description('DocumentDB compute tier')
@allowed(['M10', 'M20', 'M30', 'M40', 'M50', 'M60', 'M80', 'M200', 'M250', 'M300'])
param documentDbComputeTier string = 'M10'

@description('DocumentDB storage size in GB')
@minValue(32)
@maxValue(512)
param documentDbStorageSizeGb int = 32

@description('Enable DocumentDB high availability')
param documentDbEnableHighAvailability bool = false

// ============================================================================
// Variables
// ============================================================================

var resourceGroupName = 'rg-${workloadName}-${environment}'
var commonTags = union(tags, {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
})

var naming = {
  documentDb: 'mongodb-${workloadName}-${environment}'
}

// ============================================================================
// Resource Group
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: commonTags
}

// ============================================================================
// Module Deployments
// ============================================================================

// DocumentDB (MongoDB)
module documentDb './modules/data/documentdb.bicep' = {
  scope: rg
  name: 'documentdb-${uniqueString(deployment().name)}'
  params: {
    name: naming.documentDb
    location: location
    tags: commonTags
    adminPassword: documentDbAdminPassword
    computeTier: documentDbComputeTier
    storageSizeGb: documentDbStorageSizeGb
    enableHighAvailability: documentDbEnableHighAvailability
  }
}

// ============================================================================
// Outputs
// ============================================================================

output resourceGroupName string = rg.name
output documentDbName string = documentDb.outputs.name
output documentDbEndpoint string = documentDb.outputs.endpoint
