/**
 * AVM Quickstart Demo Workload
 * 
 * This workload demonstrates how to integrate Azure Verified Modules (AVM)
 * with cerebricep's custom modules. It deploys:
 * 
 * 1. A User-Assigned Managed Identity (cerebricep custom module)
 * 2. A Key Vault using the public AVM module (WAF-aligned)
 * 3. Access policies granting the identity permissions to the Key Vault
 * 
 * This demo shows:
 * - Module discovery using AVM registry
 * - VS Code IntelliSense with AVM modules
 * - Built-in best practices from Microsoft
 * - Parameter-driven deployments
 */

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Azure region for all resources')
param location string = 'eastus'

@description('Environment name (dev, uat, prod)')
param environment string = 'dev'

@description('Key Vault name. Must be globally unique, 3-24 chars, alphanumeric.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Enable purge protection. Set to false for dev environments.')
param enablePurgeProtection bool = false

@description('Assigned tags for all resources')
param tags object = {
  environment: environment
  workload: 'avm-quickstart'
  source: 'cerebricep'
  managedBy: 'infrastructure-team'
}

// ============================================================================
// Variables
// ============================================================================

var resourceGroupName = 'rg-avm-quickstart-${environment}'
var identityName = 'id-avm-demo-${environment}'

// ============================================================================
// Resource Group
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ============================================================================
// Identity Module (cerebricep custom module)
// ============================================================================

module identity '../../modules/identity/user-assigned-identity.bicep' = {
  scope: rg
  name: 'identity-deployment'
  params: {
    name: identityName
    location: location
    tags: tags
  }
}

// ============================================================================
// Key Vault Module (Azure Verified Module - Public Registry)
// ============================================================================
// 
// This demonstrates using a public AVM module from the Bicep Registry.
// The AVM module is:
// - WAF-aligned (security, reliability, performance best practices built-in)
// - Maintained by Microsoft
// - Discoverable via VS Code IntelliSense
// - Includes comprehensive documentation and examples
//
// Learn more: https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/key-vault/vault
//

module keyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  scope: rg
  name: 'key-vault-deployment'
  params: {
    // Required parameters
    name: keyVaultName
    
    // Security settings
    enablePurgeProtection: enablePurgeProtection
    
    // Network access - allow public access for demo (restrict in prod)
    publicNetworkAccess: 'Enabled'
    
    // RBAC assignment: Grant the managed identity 'Key Vault Secrets Officer' role
    // This allows the identity to read, create, and manage secrets
    roleAssignments: [
      {
        principalId: identity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
      }
    ]
    
    // Tags inheritance
    tags: tags
    
    // Location
    location: location
    
    // Additional optional parameters handled by AVM defaults:
    // - enableSoftDelete: true (default, recommended)
    // - softDeleteRetentionInDays: 90 (default, recommended)
    // - enableRbacAuthorization: true (recommended over vault access policies)
    // - sku: 'standard' (default)
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource Group ID')
output resourceGroupId string = rg.id

@description('Resource Group Name')
output resourceGroupName string = rg.name

@description('User-Assigned Managed Identity Resource ID')
output identityId string = identity.outputs.id

@description('User-Assigned Managed Identity Principal ID (for RBAC)')
output identityPrincipalId string = identity.outputs.principalId

@description('Key Vault Resource ID')
output keyVaultId string = keyVault.outputs.resourceId

@description('Key Vault Name')
output keyVaultName string = keyVault.outputs.name

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.uri
