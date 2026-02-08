# Security Roadmap: Phase 2 (Post-MVP)

**Document Version**: 1.0  
**Date Created**: February 8, 2026  
**Scope**: Security enhancements for production deployment  
**Timeline**: Q2-Q3 2026 (after MVP validation)  

## Phase 2 Security Vision

Transform **MVP (quick-start, non-sensitive data)** → **Production-Grade (HIPAA/GDPR-ready, multi-region resilient)**

### Phase 2 Goals

1. **Zero-Trust Network** → All internal traffic encrypted, authenticated
2. **Secrets Management** → Key Vault for all credentials
3. **Advanced Monitoring** → Application Insights, Azure Monitor
4. **API Security** → Azure AD authentication, rate limiting
5. **Compliance Ready** → HIPAA, GDPR, SOC 2 Type II
6. **Disaster Recovery** → Multi-region failover

---

## Security Upgrade 1: Key Vault Integration

**Status**: Phase 2 (Q2 2026)  
**Priority**: HIGH  
**Cost Impact**: +$0.50/month  

### Objective
Replace hardcoded SQL credentials and storage account keys with Azure Key Vault RBAC.

### Implementation

```bicep
// Phase 2: infra/modules/config/key-vault.bicep
resource keyVault 'Microsoft.KeyVault/vaults@2026-02-01' = {
  name: 'kv-healthcare-call-agent-${environment}'
  location: location
  tags: tags
  properties: {
    enableRbacAuthorization: true  // RBAC instead of access policies
    enableSoftDelete: true          // 90-day recovery
    softDeleteRetentionInDays: 90
    minimumTlsVersion: '1.2'
    sku: {
      family: 'A'
      name: 'standard'
    }
  }
}

// Grant Function App managed identity access to secrets
resource keyVaultSecretUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, functionAppPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'  // Key Vault Secrets User role
    )
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Store SQL password in Key Vault
resource sqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2026-02-01' = {
  parent: keyVault
  name: 'SqlAdminPassword'
  properties: {
    value: sqlAdminPassword
    attributes: {
      enabled: true
      exp: dateTimeToUnixTime(dateTimeAdd(utcNow(), 'P90D'))  // Expire after 90 days
    }
  }
}
```

### Deployment Steps

1. **Add Key Vault module** to healthcare-call-agent workload
2. **Migrate SQL password** from Function App app setting → Key Vault secret
3. **Update Function App** to read from Key Vault using managed identity
4. **Rotate SQL password** every 90 days (automate with Azure Automation)
5. **Decommission** hardcoded credentials from app settings

### Benefits
✅ Centralized credential management  
✅ Automatic key rotation policy  
✅ Audit log for all secret access  
✅ RBAC-based access control (no overly-permissive access policies)  

### API Version Requirement
**Current**: Key Vault 2024-*  
**Requirement**: API 2026-02-01+ by Feb 27, 2027 (Microsoft deprecation deadline)

---

## Security Upgrade 2: VNet & Private Endpoints

**Status**: Phase 2 (Q2 2026)  
**Priority**: HIGH  
**Cost Impact**: +$32/month (VNet) + $0.50/PE (3 endpoints) = ~$33/month  

### Objective
Isolate all workload traffic to private VNet; eliminate public internet exposure for backend services.

### Architecture

```
┌─────────────────────────────────────┐
│ Azure VNet (10.0.0.0/24)            │
│                                     │
│  ┌────────────────────────────────┐ │
│  │ Subnet: Compute (10.0.1.0/25)  │ │
│  │  └─ Function App (VNet-enabled)│ │
│  └────────────────────────────────┘ │
│                                     │
│  ┌────────────────────────────────┐ │
│  │ Subnet: Data (10.0.2.0/25)     │ │
│  │  ├─ SQL Private Endpoint       │ │
│  │  ├─ Storage Private Endpoint   │ │
│  │  └─ Key Vault Private Endpoint │ │
│  └────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
         ↓ (peering/ExpressRoute)
  On-premises or Partner VNet
```

### Implementation

```bicep
// Phase 2: New module infra/modules/network/vnet.bicep
resource vnet 'Microsoft.Network/virtualNetworks@2024-11-01' = {
  name: 'vnet-healthcare-call-agent-${environment}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/24']
    }
    subnets: [
      {
        name: 'compute'
        properties: {
          addressPrefix: '10.0.1.0/25'
          serviceEndpoints: [{ service: 'Microsoft.Sql' }, { service: 'Microsoft.Storage' }]
          delegations: [{ name: 'serverFarms', properties: { serviceName: 'Microsoft.Web/serverFarms' } }]
        }
      }
      {
        name: 'data'
        properties: {
          addressPrefix: '10.0.2.0/25'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Function App VNet integration
module functionAppWithVNet 'path/to/function-app.bicep' = {
  params: {
    // ... existing params ...
    vnetId: vnet.id
    subnetId: vnet.properties.subnets[0].id
  }
}

// Private Endpoints for SQL, Storage, Key Vault
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-11-01' = {
  name: 'pe-sql-healthcare-call-agent-${environment}'
  location: location
  properties: {
    subnet: { id: '${vnet.id}/subnets/data' }
    privateLinkServiceConnections: [
      {
        name: 'pe-sql-connection'
        properties: {
          privateLinkServiceId: sqlServerId
          groupIds: ['sqlServer']
        }
      }
    ]
  }
}
```

### Deployment Steps

1. **Design VNet** with compute and data subnets
2. **Enable VNet integration** on Function App
3. **Create private endpoints** for SQL, Storage, Key Vault
4. **Configure DNS private zones** for private endpoint name resolution
5. **Test connectivity** from Function App to private endpoints
6. **Monitor cross-RG access** (ACS/AI Services still via public endpoints)

### Benefits
✅ No public exposure for database / storage  
✅ DDoS mitigation (no public IPs for backend)  
✅ Network-level access control (NSGs)  
✅ Encrypted traffic (private endpoints are HTTPS-only)  

### Cost Consideration
- VNet: $32/month (fixed regional cost)
- Each Private Endpoint: $0.50/month
- Total for 3 PEs: $33.50/month
- **ROI**: Justifies for production workloads; can be shared across 3-5 workloads

---

## Security Upgrade 3: API Management & Azure AD

**Status**: Phase 2 (Q2-Q3 2026)  
**Priority**: MEDIUM-HIGH  
**Cost Impact**: +$50/month (API Mgmt) + Azure AD (free for B2C)  

### Objective
Secure Function App endpoints with authentication, rate limiting, and API governance.

### Implementation

```bicep
// Phase 2: New module infra/modules/api/api-management.bicep
resource apimService 'Microsoft.ApiManagement/service@2024-05-01-preview' = {
  name: 'apim-healthcare-call-agent-${environment}'
  location: location
  tags: tags
  sku: {
    name: 'Developer'  // $50/month; Consumption ($1.45/1M calls) for ultra-light
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@company.com'
    publisherName: 'Healthcare Call Agent Team'
    notificationSenderEmail: 'apim-noreply@microsoft.com'
  }
}

// Register Function App as API backend
resource apimBackend 'Microsoft.ApiManagement/service/backends@2024-05-01-preview' = {
  parent: apimService
  name: 'func-healthcare-call-agent-backend'
  properties: {
    title: 'Healthcare Call Agent Function'
    url: 'https://${functionAppHostname}'
    protocol: 'http'  // Private endpoint resolves to 10.0.2.x internally
  }
}

// API definition
resource apimApi 'Microsoft.ApiManagement/service/apis@2024-05-01-preview' = {
  parent: apimService
  name: 'healthcare-call-agent-api'
  properties: {
    path: 'calls'
    protocols: ['https']
    displayName: 'Healthcare Call Agent API'
    apiVersion: '1.0'
    backendId: apimBackend.id
  }
}

// Azure AD authentication policy
resource apimAuthPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01-preview' = {
  parent: apimApi
  name: 'policy'
  properties: {
    format: 'xml'
    value: '''
      <policies>
        <inbound>
          <!-- Validate JWT from Azure AD -->
          <validate-jwt header-name="Authorization" failed-validation-action="forbid">
            <openid-config url="https://login.microsoftonline.com/${tenantId}/.well-known/openid-configuration" />
            <audiences>
              <audience>${apiAppIdUri}</audience>
            </audiences>
            <issuers>
              <issuer>https://sts.windows.net/${tenantId}/</issuer>
            </issuers>
            <required-claims>
              <claim name="oid" match="any">
                <value>authenticated-users</value>
              </claim>
            </required-claims>
          </validate-jwt>
          
          <!-- Rate limiting -->
          <rate-limit calls="100" renewal-period="60" />
        </inbound>
        <backend>
          <forward-request />
        </backend>
        <outbound></outbound>
      </policies>
    '''
  }
}
```

### Deployment Steps

1. **Provision API Management** service (Developer or Consumption tier)
2. **Register Function App** as backend
3. **Create API definition** with operations
4. **Configure Azure AD authentication** (policy-based)
5. **Enable rate limiting** and quotas
6. **Test with client credentials** flow
7. **Redirect traffic** from Function App DNS → API Management DNS

### Benefits
✅ API authentication (Azure AD OAuth 2.0)  
✅ Rate limiting (prevent abuse)  
✅ API versioning and governance  
✅ Analytics and monitoring  
✅ Decouples client authentication from application code  

### Pricing Options
- **Developer**: $50/month (unlimited calls; no HA)
- **Consumption**: $1.45/1M calls (serverless; scales to zero)
- **Standard**: $300/month (HA; enterprise features)

**Recommendation**: Start with Consumption for cost-efficiency; upgrade to Developer/Standard if API governance needed.

---

## Security Upgrade 4: Advanced Monitoring & Logging

**Status**: Phase 2 (Q2 2026)  
**Priority**: MEDIUM  
**Cost Impact**: +$2-5/month (Application Insights)  

### Objective
Extended observability for security events, performance monitoring, and compliance audit trails.

### Implementation

```bicep
// Phase 2: Enhance monitoring modules
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-healthcare-call-agent-${environment}'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    IngestionMode: 'ApplicationInsights'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    RetentionInDays: 90
  }
}

// SQL Database auditing
resource sqlServerAudit 'Microsoft.Sql/servers/auditingSettings@2024-01-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    retentionDays: 90
    auditActionsAndGroups: [
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]
    storageEndpoint: storageAccount.properties.primaryEndpoints.blob
    storageAccountAccessKey: listKeys(storageAccountId, '2024-06-01').keys[0].value
    storageAccountSubscriptionId: subscription().subscriptionId
    isAzureMonitorTargetEnabled: true
  }
}

// Diagnostic settings for Function App
resource functionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: functionApp
  name: 'diag-funcapp'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
```

### Key Metrics to Track

```kusto
// KQL: Azure Monitor / Log Analytics
FunctionAppLogs
| where Level == "Error"
| summarize ErrorCount=count() by bin(TimeGenerated, 1h)

SqlServerDiagnosticsLogs
| where Statement contains "SENSITIVE_OPERATION"
| project TimeGenerated, Principal, Statement

StorageQueues
| where Name endswith "failed"
| summarize FailedCount=count() by QueueName
```

### Benefits
✅ Function App execution metrics  
✅ SQL Database audit trail  
✅ Centralized security event logging  
✅ Performance baselines for anomaly detection  
✅ HIPAA/GDPR audit compliance  

---

## Security Upgrade 5: Multi-Region Disaster Recovery

**Status**: Phase 2-3 (Q3 2026)  
**Priority**: LOW (non-critical for MVP)  
**Cost Impact**: +$122/month (secondary region infrastructure)  

### Objective
Meet RPO/RTO requirements; enable geo-redundancy for compliance.

### Implementation Strategy

```
Primary Region (East US 2)          Secondary Region (West US 2)
├─ VNet 10.0.0.0/24                ├─ VNet 10.1.0.0/24
├─ SQL Primary                       ├─ SQL Secondary
├─ Storage Account (GRS)            ├─ (via geo-replication)
├─ Function App (active)            └─ Function App (standby)
└─ Key Vault                        └─ Key Vault (replicated)
                    ↓ (VNet Peering/ExpressRoute)
              Failover Traffic Profile
              (Azure Traffic Manager)
```

### Deployment Components

1. **Replicate infrastructure** to secondary region
2. **Enable SQL geo-replication** (secondary read-only)
3. **Setup Traffic Manager** for failover routing
4. **Configure Key Vault replication** (soft delete + recovery)
5. **Test failover** quarterly
6. **Monitor replication lag** (< 5 minutes target)

### RPO/RTO Targets
- **RPO** (Recovery Point Objective): < 5 minutes (SQL geo-replication lag)
- **RTO** (Recovery Time Objective): < 10 minutes (Traffic Manager + app warmup)
- **Cost**: +$122/month (secondary region mirror)

---

## Phase 2 Implementation Timeline

```
Q2 2026 (April-June)
├─ Week 1-2: Key Vault deployment + migration
├─ Week 3-4: VNet + Private Endpoints
├─ Week 5-8: API Management + Azure AD
└─ Week 9-12: Application Insights + SQL Auditing

Q3 2026 (July-September)
├─ Week 1-4: Extended monitoring implementation
├─ Week 5-8: Security testing & penetration test
├─ Week 9-12: Multi-region DR setup
└─ End of Q3: Production-grade security achieved

Post-Launch
├─ Ongoing: Key rotation, patch management
├─ Monthly: Security log review
├─ Quarterly: DR failover test
└─ Annually: Security audit & compliance review
```

---

## Budget Estimate: Phase 2 Security

| Component | Cost/Month | Timeline |
|-----------|-----------|----------|
| Key Vault | $0.50 | Q2 |
| VNet + Private Endpoints | $33 | Q2 |
| API Management (Consumption) | $1.45/M calls | Q2-Q3 |
| Application Insights | $2-5 | Q2-Q3 |
| Multi-Region (secondary) | $122 | Q3 |
| **Total Phase 2 Monthly** | **$160-200** | After Q3 2026 |

**Incremental**: +$40-60/month vs. current $122 MVP cost

---

## Compliance Readiness Checklist (Phase 2 End)

- [ ] HIPAA Eligible Architecture
  - [ ] Encryption at rest (Key Vault + TDE)
  - [ ] Encryption in transit (private endpoints + TLS)
  - [ ] Access control (RBAC + Azure AD)
  - [ ] Audit logging (SQL + Application Insights)
  - [ ] Business Associate Agreement (BAA) signed

- [ ] GDPR Compliance
  - [ ] Data residency (EU region option)
  - [ ] Data subject rights (deletion, portability)
  - [ ] Privacy impact assessment (PIA)
  - [ ] Data processing agreement (DPA)

- [ ] SOC 2 Type II
  - [ ] Security controls documented
  - [ ] Audit evidence collected (logs, access reports)
  - [ ] Incident response plan
  - [ ] Change management process

---

## References

- [Azure Security Best Practices](https://learn.microsoft.com/en-us/azure/security/)
- [Key Vault RBAC 2026-02-01 API](https://learn.microsoft.com/en-us/azure/key-vault/general/api-versions-and-policies)
- [Private Endpoints Overview](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Azure AD Integration](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-oauth2)

---

**Document Status**: ✅ Complete  
**Next Review**: Upon Phase 1 (MVP) deployment  
**Owner**: Security & Infrastructure Team  
**Approval**: Pending Phase 1 deployment review
