// ============================================================================
// Storage Account Module
// ============================================================================

@description('Name of the storage account (must be globally unique, 3-24 lowercase letters/numbers)')
@minLength(3)
@maxLength(24)
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Principal ID of the managed identity to grant access')
param managedIdentityPrincipalId string

@description('Storage account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS'])
param sku string = 'Standard_LRS'

@description('Storage account tier')
@allowed(['Standard', 'Premium'])
param tier string = 'Standard'

@description('Storage access tier')
@allowed(['Hot', 'Cool', 'Cold'])
param accessTier string = 'Hot'

@description('Enable blob versioning')
param enableVersioning bool = true

@description('Enable blob public access')
param allowBlobPublicAccess bool = false

@description('Allow shared key access')
param allowSharedKeyAccess bool = true

@description('Minimum TLS version')
@allowed(['TLS1_0', 'TLS1_1', 'TLS1_2'])
param minimumTlsVersion string = 'TLS1_2'

@description('Allow cross-tenant replication')
param allowCrossTenantReplication bool = false

@description('Enable OAuth authentication as default')
param defaultToOAuthAuthentication bool = true

@description('Key expiration period in days for managed keys')
@minValue(7)
@maxValue(365)
param keyExpirationPeriodInDays int = 60

@description('Blob retention days for soft delete')
@minValue(1)
@maxValue(365)
param blobRetentionDays int = 7

@description('Container retention days for soft delete')
@minValue(1)
@maxValue(365)
param containerRetentionDays int = 7

@description('Enable blob immutable storage with versioning')
param enableImmutableStorage bool = false

@description('Network ACL default action (Allow or Deny)')
@allowed(['Allow', 'Deny'])
param networkAclDefaultAction string = 'Allow'

@description('Network ACL bypass rules')
@allowed(['None', 'Logging', 'Metrics', 'AzureServices', 'Logging,Metrics', 'Logging,AzureServices', 'Metrics,AzureServices', 'Logging,Metrics,AzureServices'])
param networkAclBypass string = 'AzureServices'

@description('IP rules for network ACL (array of IP addresses or CIDR ranges)')
param ipRules array = []

@description('Blob containers to create (array of container names)')
param blobContainers array = ['azure-webjobs-hosts', 'azure-webjobs-secrets']

@description('Queues to create (array of queue names)')
param queueNames array = []

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: sku
    tier: tier
  }
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    allowCrossTenantReplication: allowCrossTenantReplication
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: true
    keyPolicy: {
      keyExpirationPeriodInDays: keyExpirationPeriodInDays
    }
    networkAcls: {
      defaultAction: networkAclDefaultAction
      bypass: networkAclBypass
      ipRules: [for ip in ipRules: { value: ip }]
      virtualNetworkRules: []
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob service configuration
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storageAccount
  name: 'default'
  sku: {
    name: sku
    tier: tier
  }
  properties: {
    isVersioningEnabled: enableVersioning
    deleteRetentionPolicy: {
      enabled: true
      days: blobRetentionDays
      allowPermanentDelete: false
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: containerRetentionDays
    }
    cors: {
      corsRules: []
    }
  }
}

// File service configuration
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  sku: {
    name: sku
    tier: tier
  }
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: containerRetentionDays
    }
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: []
    }
  }
}

// Queue service configuration
resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

// Table service configuration
resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

// Blob containers
resource blobContainerResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = [
  for container in blobContainers: {
    parent: blobService
    name: container
    properties: {
      immutableStorageWithVersioning: {
        enabled: enableImmutableStorage
      }
      defaultEncryptionScope: '$account-encryption-key'
      denyEncryptionScopeOverride: false
      publicAccess: 'None'
    }
  }
]

// Queues
resource queueResource 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01' = [
  for queue in queueNames: {
    parent: queueService
    name: queue
    properties: {
      metadata: {}
    }
  }
]

// Grant managed identity Blob Data Contributor access
resource blobDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentityPrincipalId, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output id string = storageAccount.id
output name string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output fileEndpoint string = storageAccount.properties.primaryEndpoints.file
output queueEndpoint string = storageAccount.properties.primaryEndpoints.queue
output tableEndpoint string = storageAccount.properties.primaryEndpoints.table
