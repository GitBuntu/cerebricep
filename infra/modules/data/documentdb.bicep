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

@description('Storage type for the cluster')
@allowed([
  'PremiumSSD'
  'SSD'
])
param storageType string = 'PremiumSSD'

@description('Enable public network access')
param publicNetworkAccess bool = true

@description('Array of firewall rules for client IP addresses: [{name: string, startIp: string, endIp: string}]')
param firewallRules array = []

@description('Enable Data API access')
param enableDataApi bool = false

@description('Allowed authentication modes')
@allowed([
  'NativeAuth'
  'Passwordless'
])
param authMode string = 'NativeAuth'

@description('Backup retention mode (Continuous or Periodic)')
@allowed([
  'Continuous'
  'Periodic'
])
param backupRetention string = 'Continuous'

resource mongoCluster 'Microsoft.DocumentDB/mongoClusters@2025-04-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    administrator: {
      userName: adminUsername
      password: adminPassword
    }
    serverVersion: serverVersion
    compute: {
      tier: computeTier
    }
    storage: {
      sizeGb: storageSizeGb
      type: storageType
    }
    sharding: {
      shardCount: shardCount
    }
    highAvailability: {
      targetMode: enableHighAvailability ? 'ZoneRedundantPreferred' : 'Disabled'
    }
    backup: {}
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    dataApi: {
      mode: enableDataApi ? 'Enabled' : 'Disabled'
    }
    authConfig: {
      allowedModes: [
        authMode
      ]
    }
    createMode: 'Default'
  }
}

// Firewall rule to allow Azure services
resource firewallRuleAzureServices 'Microsoft.DocumentDB/mongoClusters/firewallRules@2025-04-01-preview' = {
  parent: mongoCluster
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Firewall rules for client IP addresses
resource firewallRulesCustom 'Microsoft.DocumentDB/mongoClusters/firewallRules@2025-04-01-preview' = [
  for (rule, index) in firewallRules: {
    parent: mongoCluster
    name: rule.name
    properties: {
      startIpAddress: rule.startIp
      endIpAddress: rule.endIp
    }
  }
]

// Database admin user
resource dbAdminUser 'Microsoft.DocumentDB/mongoClusters/users@2025-04-01-preview' = {
  parent: mongoCluster
  name: adminUsername
  properties: {}
}

// Outputs
output id string = mongoCluster.id
output name string = mongoCluster.name
output connectionString string = mongoCluster.properties.connectionString
output serverVersion string = mongoCluster.properties.serverVersion
output adminUsername string = adminUsername
