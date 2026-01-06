// ============================================================================
// Event Grid Module
// ============================================================================

@description('Name of the Event Grid Topic or Domain')
param name string

@description('Type of Event Grid resource')
@allowed(['topic', 'domain', 'systemTopic'])
param resourceType string = 'topic'

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('SKU for Event Grid')
@allowed(['Basic', 'Premium'])
param sku string = 'Basic'

@description('Enable public network access')
param publicNetworkAccess bool = true

@description('Enable local authentication')
param disableLocalAuth bool = false

@description('Input schema for events')
@allowed(['EventGridSchema', 'CustomEventSchema', 'CloudEventSchemaV1_0'])
param inputSchema string = 'EventGridSchema'

@description('Input schema mapping (for CustomEventSchema only)')
param inputSchemaMapping object = {}

@description('Identity type')
@allowed(['None', 'SystemAssigned', 'UserAssigned'])
param identityType string = 'None'

@description('User-assigned identity resource IDs')
param userAssignedIdentities array = []

@description('Source resource ID (for system topics only)')
param sourceResourceId string = ''

@description('Topic type (for system topics only, e.g., Microsoft.Storage.StorageAccounts)')
param topicType string = ''

@description('Enable data residency')
param dataResidencyBoundary string = 'WithinGeopair'

@description('Enable zone redundancy (Premium SKU only)')
param enableZoneRedundancy bool = false

@description('Event subscriptions to create')
param eventSubscriptions array = []

// Identity configuration
var identityConfig = identityType == 'SystemAssigned' ? {
  type: 'SystemAssigned'
} : (identityType == 'UserAssigned' ? {
  type: 'UserAssigned'
  userAssignedIdentities: reduce(userAssignedIdentities, {}, (cur, next) => union(cur, { '${next}': {} }))
} : null)

// Event Grid Topic
resource eventGridTopic 'Microsoft.EventGrid/topics@2024-06-01-preview' = if (resourceType == 'topic') {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  identity: identityConfig
  properties: {
    inputSchema: inputSchema
    inputSchemaMapping: inputSchema == 'CustomEventSchema' ? inputSchemaMapping : null
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    disableLocalAuth: disableLocalAuth
    dataResidencyBoundary: dataResidencyBoundary
  }
  zones: (sku == 'Premium' && enableZoneRedundancy) ? ['1', '2', '3'] : null
}

// Event Grid Domain
resource eventGridDomain 'Microsoft.EventGrid/domains@2024-06-01-preview' = if (resourceType == 'domain') {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  identity: identityConfig
  properties: {
    inputSchema: inputSchema
    inputSchemaMapping: inputSchema == 'CustomEventSchema' ? inputSchemaMapping : null
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    disableLocalAuth: disableLocalAuth
    dataResidencyBoundary: dataResidencyBoundary
  }
  zones: (sku == 'Premium' && enableZoneRedundancy) ? ['1', '2', '3'] : null
}

// Event Grid System Topic
resource eventGridSystemTopic 'Microsoft.EventGrid/systemTopics@2024-06-01-preview' = if (resourceType == 'systemTopic') {
  name: name
  location: location
  tags: tags
  identity: identityConfig
  properties: {
    source: sourceResourceId
    topicType: topicType
  }
}

// Event Subscriptions (for topics)
resource topicEventSubscriptions 'Microsoft.EventGrid/topics/eventSubscriptions@2024-06-01-preview' = [for subscription in eventSubscriptions: if (resourceType == 'topic') {
  parent: eventGridTopic
  name: subscription.name
  properties: {
    destination: subscription.destination
    filter: contains(subscription, 'filter') ? subscription.filter : {
      includedEventTypes: ['All']
    }
    labels: contains(subscription, 'labels') ? subscription.labels : []
    eventDeliverySchema: contains(subscription, 'eventDeliverySchema') ? subscription.eventDeliverySchema : 'EventGridSchema'
    retryPolicy: contains(subscription, 'retryPolicy') ? subscription.retryPolicy : {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
    deadLetterDestination: contains(subscription, 'deadLetterDestination') ? subscription.deadLetterDestination : null
  }
}]

// Event Subscriptions (for domains)
resource domainEventSubscriptions 'Microsoft.EventGrid/domains/eventSubscriptions@2024-06-01-preview' = [for subscription in eventSubscriptions: if (resourceType == 'domain') {
  parent: eventGridDomain
  name: subscription.name
  properties: {
    destination: subscription.destination
    filter: contains(subscription, 'filter') ? subscription.filter : {
      includedEventTypes: ['All']
    }
    labels: contains(subscription, 'labels') ? subscription.labels : []
    eventDeliverySchema: contains(subscription, 'eventDeliverySchema') ? subscription.eventDeliverySchema : 'EventGridSchema'
    retryPolicy: contains(subscription, 'retryPolicy') ? subscription.retryPolicy : {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
    deadLetterDestination: contains(subscription, 'deadLetterDestination') ? subscription.deadLetterDestination : null
  }
}]

// Event Subscriptions (for system topics)
resource systemTopicEventSubscriptions 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-06-01-preview' = [for subscription in eventSubscriptions: if (resourceType == 'systemTopic') {
  parent: eventGridSystemTopic
  name: subscription.name
  properties: {
    destination: subscription.destination
    filter: contains(subscription, 'filter') ? subscription.filter : {
      includedEventTypes: ['All']
    }
    labels: contains(subscription, 'labels') ? subscription.labels : []
    eventDeliverySchema: contains(subscription, 'eventDeliverySchema') ? subscription.eventDeliverySchema : 'EventGridSchema'
    retryPolicy: contains(subscription, 'retryPolicy') ? subscription.retryPolicy : {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
    deadLetterDestination: contains(subscription, 'deadLetterDestination') ? subscription.deadLetterDestination : null
  }
}]

// Outputs
output id string = resourceType == 'topic' ? eventGridTopic.id : (resourceType == 'domain' ? eventGridDomain.id : eventGridSystemTopic.id)
output name string = resourceType == 'topic' ? eventGridTopic.name : (resourceType == 'domain' ? eventGridDomain.name : eventGridSystemTopic.name)
output endpoint string = resourceType == 'topic' ? eventGridTopic.properties.endpoint : (resourceType == 'domain' ? eventGridDomain.properties.endpoint : '')
output principalId string = identityType == 'SystemAssigned' ? (resourceType == 'topic' ? eventGridTopic.identity.principalId : (resourceType == 'domain' ? eventGridDomain.identity.principalId : eventGridSystemTopic.identity.principalId)) : ''
