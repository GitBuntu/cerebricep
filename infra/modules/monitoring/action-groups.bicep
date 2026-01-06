// ============================================================================
// Action Group Module
// ============================================================================

@description('Name of the Action Group')
param name string

@description('Location for the resource (must be global)')
param location string = 'global'

@description('Tags to apply to the resource')
param tags object = {}

@description('Short name for SMS notifications (max 12 chars)')
@maxLength(12)
param shortName string

@description('Enable the action group')
param enabled bool = true

@description('Email receivers')
param emailReceivers array = []

@description('SMS receivers')
param smsReceivers array = []

@description('Webhook receivers')
param webhookReceivers array = []

@description('Azure Function receivers')
param azureFunctionReceivers array = []

@description('Logic App receivers')
param logicAppReceivers array = []

@description('Azure App Push receivers')
param azureAppPushReceivers array = []

@description('Automation runbook receivers')
param automationRunbookReceivers array = []

@description('Voice receivers')
param voiceReceivers array = []

@description('ARM role receivers')
param armRoleReceivers array = []

@description('Event Hub receivers')
param eventHubReceivers array = []

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    groupShortName: shortName
    enabled: enabled
    emailReceivers: [for receiver in emailReceivers: {
      name: receiver.name
      emailAddress: receiver.emailAddress
      useCommonAlertSchema: contains(receiver, 'useCommonAlertSchema') ? receiver.useCommonAlertSchema : true
    }]
    smsReceivers: [for receiver in smsReceivers: {
      name: receiver.name
      countryCode: receiver.countryCode
      phoneNumber: receiver.phoneNumber
    }]
    webhookReceivers: [for receiver in webhookReceivers: {
      name: receiver.name
      serviceUri: receiver.serviceUri
      useCommonAlertSchema: contains(receiver, 'useCommonAlertSchema') ? receiver.useCommonAlertSchema : true
      useAadAuth: contains(receiver, 'useAadAuth') ? receiver.useAadAuth : false
      objectId: contains(receiver, 'objectId') ? receiver.objectId : ''
      identifierUri: contains(receiver, 'identifierUri') ? receiver.identifierUri : ''
      tenantId: contains(receiver, 'tenantId') ? receiver.tenantId : ''
    }]
    azureFunctionReceivers: [for receiver in azureFunctionReceivers: {
      name: receiver.name
      functionAppResourceId: receiver.functionAppResourceId
      functionName: receiver.functionName
      httpTriggerUrl: receiver.httpTriggerUrl
      useCommonAlertSchema: contains(receiver, 'useCommonAlertSchema') ? receiver.useCommonAlertSchema : true
    }]
    logicAppReceivers: [for receiver in logicAppReceivers: {
      name: receiver.name
      resourceId: receiver.resourceId
      callbackUrl: receiver.callbackUrl
      useCommonAlertSchema: contains(receiver, 'useCommonAlertSchema') ? receiver.useCommonAlertSchema : true
    }]
    azureAppPushReceivers: [for receiver in azureAppPushReceivers: {
      name: receiver.name
      emailAddress: receiver.emailAddress
    }]
    automationRunbookReceivers: [for receiver in automationRunbookReceivers: {
      automationAccountId: receiver.automationAccountId
      runbookName: receiver.runbookName
      webhookResourceId: receiver.webhookResourceId
      isGlobalRunbook: receiver.isGlobalRunbook
      name: receiver.name
      serviceUri: contains(receiver, 'serviceUri') ? receiver.serviceUri : ''
      useCommonAlertSchema: contains(receiver, 'useCommonAlertSchema') ? receiver.useCommonAlertSchema : true
    }]
    voiceReceivers: [for receiver in voiceReceivers: {
      name: receiver.name
      countryCode: receiver.countryCode
      phoneNumber: receiver.phoneNumber
    }]
    armRoleReceivers: [for receiver in armRoleReceivers: {
      name: receiver.name
      roleId: receiver.roleId
      useCommonAlertSchema: contains(receiver, 'useCommonAlertSchema') ? receiver.useCommonAlertSchema : true
    }]
    eventHubReceivers: [for receiver in eventHubReceivers: {
      name: receiver.name
      eventHubNameSpace: receiver.eventHubNameSpace
      eventHubName: receiver.eventHubName
      subscriptionId: receiver.subscriptionId
      tenantId: contains(receiver, 'tenantId') ? receiver.tenantId : tenant().tenantId
      useCommonAlertSchema: contains(receiver, 'useCommonAlertSchema') ? receiver.useCommonAlertSchema : true
    }]
  }
}

// Outputs
output id string = actionGroup.id
output name string = actionGroup.name
