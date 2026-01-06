// ============================================================================
// Cosmos DB Module (MongoDB API)
// ============================================================================

@description('Name of the Cosmos DB account')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Principal ID of the managed identity to grant access')
param managedIdentityPrincipalId string

@description('Provisioned throughput (RU/s) - set to 0 for serverless')
@minValue(0)
@maxValue(1000000)
param throughput int = 400

@description('Enable zone redundancy')
param enableZoneRedundancy bool = false

@description('Default database name')
param databaseName string = 'app-data'

@description('MongoDB server version')
@allowed(['3.6', '4.0', '4.2', '5.0', '6.0', '7.0'])
param mongoServerVersion string = '4.2'

@description('Enable free tier (cannot be combined with provisioned throughput)')
param enableFreeTier bool = false

@description('Enable automatic failover')
param enableAutomaticFailover bool = false

@description('Enable multiple write locations')
param enableMultipleWriteLocations bool = false

@description('Enable analytical storage')
param enableAnalyticalStorage bool = false

@description('Backup policy type')
@allowed(['Continuous', 'Periodic'])
param backupPolicyType string = 'Continuous'

@description('Backup interval in minutes (Periodic only)')
@minValue(60)
@maxValue(1440)
param backupIntervalInMinutes int = 240

@description('Backup retention in hours (Periodic only)')
@minValue(8)
@maxValue(720)
param backupRetentionInHours int = 8

@description('IP rules for firewall (array of IP addresses or CIDR ranges)')
param ipRules array = []

@description('Virtual network rules (array of subnet resource IDs)')
param virtualNetworkRules array = []

@description('Allowed origins for CORS')
param corsAllowedOrigins array = []

// Determine if serverless
var isServerless = throughput == 0
var capabilities = concat(
  [{ name: 'EnableMongo' }],
  isServerless ? [{ name: 'EnableServerless' }] : []
)

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: name
  location: location
  tags: tags
  kind: 'MongoDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: enableFreeTier
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: enableZoneRedundancy
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    capabilities: capabilities
    apiProperties: {
      serverVersion: mongoServerVersion
    }
    disableLocalAuth: true
    enableAutomaticFailover: enableAutomaticFailover
    enableMultipleWriteLocations: enableMultipleWriteLocations
    enableAnalyticalStorage: enableAnalyticalStorage
    publicNetworkAccess: 'Enabled'
    networkAclBypass: 'AzureServices'
    ipRules: [for rule in ipRules: {
      ipAddressOrRange: rule
    }]
    virtualNetworkRules: [for rule in virtualNetworkRules: {
      id: rule
    }]
    cors: empty(corsAllowedOrigins) ? [] : [
      {
        allowedOrigins: join(corsAllowedOrigins, ',')
      }
    ]
    backupPolicy: backupPolicyType == 'Continuous' ? {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous30Days'
      }
    } : {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: backupIntervalInMinutes
        backupRetentionIntervalInHours: backupRetentionInHours
      }
    }
  }
}

// MongoDB Database
resource mongoDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: isServerless ? {} : {
      throughput: throughput
    }
  }
}

// Grant managed identity access via RBAC
// Note: MongoDB uses the same Cosmos DB Data Contributor role assignment pattern
resource mongoRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cosmosAccount
  name: guid(cosmosAccount.id, managedIdentityPrincipalId, 'CosmosDBDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '230815da-be43-4aae-9cb4-875f7bd000aa')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output id string = cosmosAccount.id
output name string = cosmosAccount.name
output endpoint string = cosmosAccount.properties.documentEndpoint
output databaseName string = mongoDatabase.name
output mongoServerVersion string = mongoServerVersion
output connectionString string = 'mongodb://${cosmosAccount.name}:${listKeys(cosmosAccount.id, cosmosAccount.apiVersion).primaryMasterKey}@${cosmosAccount.name}.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000'
