// ============================================================================
// Log Analytics Workspace Module
// ============================================================================

@description('Name of the Log Analytics workspace')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Log Analytics retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Log Analytics SKU')
@allowed(['PerGB2018', 'CapacityReservation'])
param sku string = 'PerGB2018'

@description('Daily data cap in GB (0 = no cap)')
@minValue(0)
param dailyQuotaGb int = 0

@description('Enable log access using only resource permissions')
param enableLogAccessUsingOnlyResourcePermissions bool = true

@description('Enable public network access for ingestion')
param publicNetworkAccessForIngestion bool = true

@description('Enable public network access for query')
param publicNetworkAccessForQuery bool = true

@description('Array of custom table definitions')
param customTables array = []

@description('Array of saved search definitions')
param savedSearches array = []

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    workspaceCapping: dailyQuotaGb > 0 ? {
      dailyQuotaGb: dailyQuotaGb
    } : null
    features: {
      enableLogAccessUsingOnlyResourcePermissions: enableLogAccessUsingOnlyResourcePermissions
    }
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion ? 'Enabled' : 'Disabled'
    publicNetworkAccessForQuery: publicNetworkAccessForQuery ? 'Enabled' : 'Disabled'
  }
}

// Custom tables - parameterized for flexibility
resource tables 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = [for table in customTables: {
  parent: logAnalytics
  name: table.name
  properties: {
    schema: {
      name: table.name
      columns: table.columns
    }
    retentionInDays: contains(table, 'retentionInDays') ? table.retentionInDays : retentionInDays
    totalRetentionInDays: contains(table, 'totalRetentionInDays') ? table.totalRetentionInDays : retentionInDays
  }
}]

// Saved searches - parameterized for flexibility
resource searches 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = [for search in savedSearches: {
  parent: logAnalytics
  name: search.name
  properties: {
    category: search.category
    displayName: search.displayName
    query: search.query
    version: contains(search, 'version') ? search.version : 2
    tags: contains(search, 'tags') ? search.tags : []
  }
}]

// Outputs
output id string = logAnalytics.id
output name string = logAnalytics.name
output workspaceId string = logAnalytics.properties.customerId
output primarySharedKey string = logAnalytics.listKeys().primarySharedKey
