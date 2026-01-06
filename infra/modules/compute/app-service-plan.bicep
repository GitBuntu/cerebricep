// ============================================================================
// App Service Plan Module
// ============================================================================

@description('Name of the App Service Plan')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('SKU for the App Service Plan')
@allowed(['Y1', 'EP1', 'EP2', 'EP3', 'P1V2', 'P2V2', 'P3V2', 'Flex'])
param sku string = 'Y1'

@description('Maximum elastic worker count (for non-consumption plans)')
@minValue(1)
@maxValue(100)
param maximumElasticWorkerCount int = 20

@description('Enable zone redundancy (requires Premium tier)')
param enableZoneRedundancy bool = false

// Determine plan characteristics based on SKU
var isConsumption = sku == 'Y1'
var isFlex = sku == 'Flex'
var isPremium = startsWith(sku, 'P')
var isElastic = startsWith(sku, 'EP')

var planKind = isConsumption ? 'functionapp' : (isElastic ? 'elastic' : 'linux')
var skuTier = isConsumption ? 'Dynamic' : (isFlex ? 'FlexConsumption' : (isElastic ? 'ElasticPremium' : 'PremiumV2'))
var skuName = isFlex ? 'FC1' : sku

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: name
  location: location
  tags: tags
  kind: planKind
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    reserved: true // Linux
    maximumElasticWorkerCount: isConsumption ? null : maximumElasticWorkerCount
    zoneRedundant: enableZoneRedundancy && (isPremium || isElastic)
    perSiteScaling: false
  }
}

// Outputs
output id string = appServicePlan.id
output name string = appServicePlan.name
output sku string = sku
output isConsumption bool = isConsumption
output isFlex bool = isFlex
