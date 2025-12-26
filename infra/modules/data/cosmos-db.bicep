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
@allowed(['3.6', '4.0', '4.2', '5.0'])
param mongoServerVersion string = '4.2'

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
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Enabled'
    networkAclBypass: 'AzureServices'
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
