// ============================================================================
// App Configuration Module (Feature Flags)
// ============================================================================

@description('Name of the App Configuration store')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Principal ID of the managed identity to grant access')
param managedIdentityPrincipalId string

@description('SKU for App Configuration')
@allowed(['Free', 'Standard'])
param sku string = 'Standard'

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2024-06-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    disableLocalAuth: true
    enablePurgeProtection: sku == 'Standard'
    publicNetworkAccess: 'Enabled'
  }
}

// Grant managed identity Data Reader access
resource dataReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appConfig.id, managedIdentityPrincipalId, 'App Configuration Data Reader')
  scope: appConfig
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '516239f1-63e1-4d78-a4de-a74fb236a071') // App Configuration Data Reader
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output id string = appConfig.id
output name string = appConfig.name
output endpoint string = appConfig.properties.endpoint
