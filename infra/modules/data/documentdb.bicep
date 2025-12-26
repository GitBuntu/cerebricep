// ============================================================================
// Azure DocumentDB Module (MongoDB Cluster)
// ============================================================================

@description('Name of the DocumentDB cluster')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Admin username for the cluster')
param adminUsername string = 'dbadmin'

@description('Admin password for the cluster (should be from Key Vault)')
@secure()
param adminPassword string

@description('MongoDB server version')
@allowed([
  '4.2'
  '5.0'
  '6.0'
  '7.0'
  '8.0'
])
param serverVersion string = '8.0'

@description('Number of shards in the cluster')
@minValue(1)
@maxValue(3)
param shardCount int = 1

@description('Storage size in GB')
@minValue(32)
@maxValue(512)
param storageSizeGb int = 32

@description('Compute tier (M10, M20, M30, M40, M50, M60, M80, M200, M250, M300)')
@allowed([
  'M10'
  'M20'
  'M30'
  'M40'
  'M50'
  'M60'
  'M80'
  'M200'
  'M250'
  'M300'
])
param computeTier string = 'M10'

@description('Enable high availability')
param enableHighAvailability bool = false

resource mongoCluster 'Microsoft.DocumentDB/mongoClusters@2025-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    administrator: {
      userName: adminUsername
      password: adminPassword
    }
    serverVersion: serverVersion
    sharding: {
      shardCount: shardCount
    }
    storage: {
      sizeGb: storageSizeGb
    }
    highAvailability: {
      targetMode: enableHighAvailability ? 'ZoneRedundantPreferred' : 'Disabled'
    }
    compute: {
      tier: computeTier
    }
  }
}

// Firewall rule to allow Azure services
resource firewallRuleAzureServices 'Microsoft.DocumentDB/mongoClusters/firewallRules@2025-09-01' = {
  parent: mongoCluster
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Outputs
output id string = mongoCluster.id
output name string = mongoCluster.name
output endpoint string = mongoCluster.properties.connectionString
output serverVersion string = mongoCluster.properties.serverVersion
