// ============================================================================
// Key Vault Module
// ============================================================================

@description('Name of the Key Vault')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Principal ID of the managed identity to grant access')
param managedIdentityPrincipalId string

@description('Enable private endpoint')
param enablePrivateEndpoint bool = false

@description('Enable soft delete')
param enableSoftDelete bool = true

@description('Soft delete retention in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection')
param enablePurgeProtection bool = true

@description('Enable Key Vault for template deployment')
param enabledForTemplateDeployment bool = false

@description('Enable Key Vault for disk encryption')
param enabledForDiskEncryption bool = false

@description('Enable Key Vault for resource deployment')
param enabledForDeployment bool = false

@description('Key Vault SKU name')
@allowed(['standard', 'premium'])
param skuName string = 'standard'

@description('Key Vault SKU family')
param skuFamily string = 'A'

@description('Network ACL default action')
@allowed(['Allow', 'Deny'])
param networkAclDefaultAction string = 'Allow'

@description('Network ACL bypass rules')
@allowed(['None', 'AzureServices', 'Logging', 'Metrics', 'Logging,Metrics', 'Logging,AzureServices', 'Metrics,AzureServices', 'Logging,Metrics,AzureServices'])
param networkAclBypass string = 'AzureServices'

@description('Secrets to create in Key Vault (array of {name: string, value: string})')
param secrets array = []

@description('Enable RBAC authorization')
param enableRbacAuthorization bool = true

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: skuFamily
      name: skuName
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForDeployment: enabledForDeployment
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    networkAcls: {
      defaultAction: enablePrivateEndpoint ? 'Deny' : networkAclDefaultAction
      bypass: networkAclBypass
    }
  }
}

// Grant managed identity access to secrets
resource secretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Create secrets in Key Vault
resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = [
  for secret in secrets: {
    parent: keyVault
    name: secret.name
    properties: {
      value: secret.value
      attributes: {
        enabled: true
      }
    }
  }
]

// Outputs
output id string = keyVault.id
output name string = keyVault.name
output uri string = keyVault.properties.vaultUri
output secretNames array = [for secret in secrets: secret.name]
