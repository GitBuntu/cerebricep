// ============================================================================
// Application Insights Module
// ============================================================================

@description('Name of the Application Insights resource')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Application type')
@allowed(['web', 'other', 'java', 'phone', 'store', 'ios', 'android', 'Node.JS'])
param applicationType string = 'web'

@description('Log Analytics workspace resource ID')
param workspaceResourceId string

@description('Enable public network access for ingestion')
param publicNetworkAccessForIngestion bool = true

@description('Enable public network access for query')
param publicNetworkAccessForQuery bool = true

@description('Retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('Daily data cap in GB (0 = no cap)')
@minValue(0)
param dailyDataCapInGB int = 0

@description('Enable daily data cap warning')
param disableIpMasking bool = false

@description('Sampling percentage (0-100)')
@minValue(0)
@maxValue(100)
param samplingPercentage int = 100

@description('Enable smart detection alert rules')
param enableSmartDetection bool = true

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion ? 'Enabled' : 'Disabled'
    publicNetworkAccessForQuery: publicNetworkAccessForQuery ? 'Enabled' : 'Disabled'
    RetentionInDays: retentionInDays
    SamplingPercentage: samplingPercentage
    DisableIpMasking: disableIpMasking
    Flow_Type: 'Bluefield'
  }
}

// Daily cap configuration (if specified)
resource dailyCap 'Microsoft.Insights/components/currentbillingfeatures@2015-05-01' = if (dailyDataCapInGB > 0) {
  parent: appInsights
  name: 'Basic'
  properties: {
    DataVolumeCap: {
      Cap: dailyDataCapInGB
    }
  }
}

// Smart Detection: Slow page load time
resource smartDetectionSlowPageLoad 'Microsoft.AlertsManagement/smartDetectorAlertRules@2021-04-01' = if (enableSmartDetection) {
  name: '${name}-slow-page-load'
  location: 'global'
  properties: {
    description: 'Detects slow page load times in your application'
    state: 'Enabled'
    severity: 'Sev3'
    frequency: 'PT1M'
    detector: {
      id: 'SlowPageLoadTimeDetector'
    }
    scope: [appInsights.id]
    actionGroups: {
      groupIds: []
    }
  }
}

// Smart Detection: Slow server response time
resource smartDetectionSlowServerResponse 'Microsoft.AlertsManagement/smartDetectorAlertRules@2021-04-01' = if (enableSmartDetection) {
  name: '${name}-slow-server-response'
  location: 'global'
  properties: {
    description: 'Detects slow server response times'
    state: 'Enabled'
    severity: 'Sev3'
    frequency: 'PT1M'
    detector: {
      id: 'SlowServerResponseTimeDetector'
    }
    scope: [appInsights.id]
    actionGroups: {
      groupIds: []
    }
  }
}

// Smart Detection: Degradation in dependency duration
resource smartDetectionDependencyDegradation 'Microsoft.AlertsManagement/smartDetectorAlertRules@2021-04-01' = if (enableSmartDetection) {
  name: '${name}-dependency-degradation'
  location: 'global'
  properties: {
    description: 'Detects degradation in dependency call duration'
    state: 'Enabled'
    severity: 'Sev3'
    frequency: 'PT1M'
    detector: {
      id: 'DependencyPerformanceDegradationDetector'
    }
    scope: [appInsights.id]
    actionGroups: {
      groupIds: []
    }
  }
}

// Smart Detection: Failure anomalies
resource smartDetectionFailureAnomalies 'Microsoft.AlertsManagement/smartDetectorAlertRules@2021-04-01' = if (enableSmartDetection) {
  name: '${name}-failure-anomalies'
  location: 'global'
  properties: {
    description: 'Detects unusual patterns in failure rates'
    state: 'Enabled'
    severity: 'Sev3'
    frequency: 'PT1M'
    detector: {
      id: 'FailureAnomaliesDetector'
    }
    scope: [appInsights.id]
    actionGroups: {
      groupIds: []
    }
  }
}

// Outputs
output id string = appInsights.id
output name string = appInsights.name
output connectionString string = appInsights.properties.ConnectionString
output instrumentationKey string = appInsights.properties.InstrumentationKey
output appId string = appInsights.properties.AppId
