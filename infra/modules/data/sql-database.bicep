// ============================================================================
// Azure SQL Database Module
// ============================================================================
// Purpose: Deploy Azure SQL Server and Database resources
// Scope: Resource Group
// Parameters: location, tags, serverName, databaseName, adminUsername, 
//            adminPassword, sku, collation
// Outputs: serverFqdn, databaseId, adonetConnectionString

@description('Location for the resources')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('Name of the SQL Server (must be globally unique)')
@minLength(1)
@maxLength(63)
param serverName string

@description('Name of the SQL Database')
@minLength(1)
@maxLength(128)
param databaseName string

@description('SQL Server admin username')
@minLength(1)
@maxLength(128)
param adminUsername string

@description('SQL Server admin password (sensitive)')
@secure()
param adminPassword string

@description('SQL Database SKU (e.g., Basic, Standard_S0)')
param sku string = 'Basic'

@description('SQL Database collation')
param collation string = 'SQL_Latin1_General_CP1_CI_AS'

@description('Database max size in GB')
param maxSizeGb int = 2

@description('Whether to allow Azure services to access the server')
param allowAzureServicesAccess bool = true

// ============================================================================
// Resources
// ============================================================================

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
  name: serverName
  location: location
  tags: tags
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku == 'Basic' ? 'Basic' : (startsWith(sku, 'Standard') ? 'Standard' : 'Premium')
  }
  properties: {
    collation: collation
    maxSizeBytes: maxSizeGb * 1024 * 1024 * 1024
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    licenseType: 'LicenseIncluded'
    readScale: 'Disabled'
  }
}

// Firewall rule to allow Azure services
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-08-01' = if (allowAzureServicesAccess) {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('SQL Server fully qualified domain name')
output serverFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('SQL Server resource ID')
output serverId string = sqlServer.id

@description('SQL Server name')
output serverName string = sqlServer.name

@description('SQL Database resource ID')
output databaseId string = sqlDatabase.id

@description('SQL Database name')
output databaseName string = sqlDatabase.name

@description('ADO.NET Connection String (for managed identity)')
output adonetConnectionString string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${databaseName};Encrypt=true;Connection Timeout=30;'
