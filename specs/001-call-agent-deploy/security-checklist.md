# Security Checklist: Healthcare Call Agent MVP

**Document Version**: 1.0  
**Date Created**: February 8, 2026  
**Scope**: MVP security posture (what IS protected)  
**Compliance**: HIPAA Eligible (storage encryption), GDPR-aware  

## Security Posture: MVP vs. Phase 2

### MVP Implementation (February 2026)

The Healthcare Call Agent MVP implements **essential security controls** suitable for non-sensitive test data and initial deployments, with a clear Phase 2 hardening roadmap.

---

## MVP Security Controls ✅

### 1. Identity & Access Control

| Control | MVP Status | Implementation | Verification |
|---------|-----------|-----------------|--------------|
| **Service Principal + RBAC** | ✅ YES | GitHub Actions uses federated identity (OIDC) | Configured in `.github/workflows/deploy-*.yml` |
| **User-Assigned Managed Identity** | ✅ YES | Function App uses managed identity for Azure access | Identity module deployed; outputs captured |
| **SQL Authentication** | ⚠️ PARTIAL | SQL admin user + password (not production-ready) | Stored in deployment parameters; MVP only |
| **Source Code Access Control** | ✅ YES | GitHub repository; branch protection rules | OIDC prevents credential leakage |

**MVP Sufficiency**: ✓ Adequate for non-production + internal testing  
**Phase 2 Upgrade**: Key Vault + RBAC for credential management

---

### 2. Network Security

| Control | MVP Status | Implementation |
|---------|-----------|-----------------|
| **HTTPS/TLS Enforcement** | ✅ YES | Function App httpsOnly: true |
| **Public Endpoints** | ⚠️ EXPOSED | Functions accessible from public internet |
| **SQL Firewall** | ✅ PARTIAL | Allows Azure Services; no IP restrictions |
| **VNet Integration** | ❌ NO | Not in MVP; Phase 2 feature |
| **Private Endpoints** | ❌ NO | Not in MVP; Phase 2 feature |
| **DDoS Protection** | ❌ NO | Relies on Azure DDoS Standard |

**MVP Risk**: Functions publicly accessible; SQL open to all Azure services  
**Phase 2 Hardening**: VNet, private endpoints, WAF

---

### 3. Data Protection

| Control | MVP Status | Implementation |
|---------|-----------|-----------------|
| **Encryption at Rest** | ✅ YES | Storage Account: Encryption enabled (Microsoft-managed keys) |
| **Encryption in Transit** | ✅ YES | TLS 1.2+ for all endpoints |
| **Database Encryption** | ✅ YES | SQL Database: Transparent Data Encryption (TDE) enabled |
| **Key Management** | ❌ NO | Using storage account default keys (not Key Vault) |
| **Backup Encryption** | ✅ YES | SQL backups encrypted with account keys |
| **Blob Versioning** | ✅ YES | Storage Account blob versioning enabled |

**MVP Risk**: Encryption keys managed by Azure; no BYOK (Bring Your Own Key)  
**Phase 2 Upgrade**: Key Vault for key management

---

### 4. Application Security

| Control | MVP Status | Implementation |
|---------|-----------|-----------------|
| **Secure Parameter Defaults** | ✅ YES | Bicep linting enforced in bicepconfig.json |
| **No Hardcoded Secrets** | ✅ YES | Credentials passed at deployment time |
| **HTTPS Redirects** | ✅ YES | Function App HTTPS-only |
| **CORS Policy** | ✅ YES | Restricted to `portal.azure.com` |
| **TLS Version** | ✅ YES | Minimum TLS 1.2 |
| **Authentication/Authorization** | ⚠️ PARTIAL | Azure AD integration optional; not enforced in MVP |

**MVP Gaps**: No built-in authentication on Functions; reliant on application code  
**Phase 2**: Azure AD B2C / API Management with authentication

---

### 5. Audit & Compliance

| Control | MVP Status | Implementation |
|---------|-----------|-----------------|
| **Resource Tagging** | ✅ YES | All resources tagged: workload, environment, managedBy |
| **Activity Logging** | ✅ YES | Azure Activity Log captures all API calls |
| **SQL Audit** | ⚠️ PARTIAL | SQL Database audit trail (Activity Log); SQL Auditing not enabled |
| **Storage Access Logging** | ✅ YES | Storage Account logging enabled for blobs |
| **Cross-RG tracking** | ✅ YES | Activity logs include cross-RG resource queries |

**MVP Compliance**: Suitable for audit trail; not comprehensive  
**Phase 2**: Enable SQL Server Auditing, Application Insights diagnostics

---

### 6. Vulnerability Management

| Control | MVP Status | Implementation |
|---------|-----------|---|
| **Dependency Scanning** | ✅ YES | Bicep lint checks (bicepconfig.json) |
| **Container Image Scan** | N/A | No containers in MVP |
| **API Version Compliance** | ⚠️ PARTIAL | Using recent APIs; some preview versions |
| **Security Updates** | ✅ YES | Azure PaaS handles patching automatically |

**MVP Approach**: Relies on Azure managed service security updates  
**Phase 2**: Add dependency scanning for code

---

## Security Checklist (Pre-Deployment)

### Infrastructure

- [ ] **Bicep templates reviewed** for security best practices
  - [ ] No hardcoded credentials
  - [ ] All secrets marked @secure()
  - [ ] HTTPS enforcement enabled
  - [ ] Minimum TLS 1.2
  - [ ] Public network access reviewed

- [ ] **GitHub Actions workflow secured**
  - [ ] OIDC federated identity configured
  - [ ] No PAT (Personal Access Tokens) used
  - [ ] Role assignments follow least-privilege
  - [ ] Secrets stored in GitHub environment variables
  - [ ] Deployment approvals for prod environment

- [ ] **Parameter files configured**
  - [ ] sqlAdminPassword set (temp; Phase 2 → Key Vault)
  - [ ] Shared resource names verified
  - [ ] No credentials in version control

### Network

- [ ] **HTTPS enforcement**
  - [ ] Function App: httpsOnly = true
  - [ ] TLS version: 1.2+
  - [ ] CORS policy restricted

- [ ] **SQL Firewall**
  - [ ] AllowAzureServices enabled (for Function App)
  - [ ] No overly permissive IP ranges
  - [ ] Database admin account password strong

### Data

- [ ] **Encryption at rest**
  - [ ] Storage Account encryption enabled
  - [ ] SQL Database TDE enabled
  - [ ] Backups encrypted

- [ ] **Encryption in transit**
  - [ ] All connections use HTTPS/TLS
  - [ ] No unencrypted data flows

### Access Control

- [ ] **Managed Identity configured**
  - [ ] Function App assigned managed identity
  - [ ] MSI has necessary RBAC roles
  - [ ] No SQL password hardcoded in app settings

- [ ] **GitHub Actions RBAC**
  - [ ] Service Principal has Contributor (minimum scope)
  - [ ] Reader role on shared resource group verified
  - [ ] No subscription-level admin roles

### Audit & Logs

- [ ] **Resource tagging** applied to all resources
  - [ ] workload: healthcare-call-agent
  - [ ] environment: dev/uat/prod
  - [ ] managedBy: IaC

- [ ] **Activity Log monitoring** enabled
  - [ ] Cross-RG resource queries tracked
  - [ ] Deployment events captured
  - [ ] Alerts configured for failures

---

## Post-Deployment Security Verification

```bash
# 1. Verify HTTPS enforcement
az functionapp config appsettings list \
  -g rg-healthcare-call-agent-prod \
  -n func-healthcare-call-agent-prod \
  | grep -i "httpsonly\|tls\|ssl"

# 2. Check SQL firewall rules
az sql server firewall-rule list \
  -g rg-healthcare-call-agent-prod \
  -s sql-healthcare-call-agent-prod

# 3. Verify encryption at rest
az storage account show \
  -g rg-healthcare-call-agent-prod \
  -n stHCagent... \
  --query "encryption"

# 4. Validate managed identity
az functionapp identity show \
  -g rg-healthcare-call-agent-prod \
  -n func-healthcare-call-agent-prod

# 5. Review activity log
az monitor activity-log list \
  --resource-group rg-healthcare-call-agent-prod \
  --max-items 50 \
  --output table
```

---

## MVP Security Gaps & Phase 2 Roadmap

| Concern | Impact | MVP Status | Phase 2 Solution | Timeline |
|---------|--------|-----------|------------------|----------|
| **Key Management** | HIGH | Unencrypted keys | Key Vault + RBAC | Q2 2026 |
| **Network Isolation** | HIGH | Public endpoints | VNet + Private Endpoints | Q2 2026 |
| **SQL Authentication** | MEDIUM | Admin user/password | Managed Identity + RBAC | Q2 2026 |
| **Data Classification** | LOW | Not labeled | GDPR/HIPAA tags | Q3 2026 |
| **Advanced Monitoring** | MEDIUM | Basic logs | Application Insights | Q2 2026 |
| **API Authentication** | MEDIUM | Function public | Azure AD / API Mgmt | Q2 2026 |
| **Multi-Region DR** | LOW | Single region | Failover region | Q3 2026 |

### Phase 2 Security Roadmap (Q1-Q2 2026)

**Priority 1: Credential Management**
- [ ] Deploy Azure Key Vault
- [ ] Migrate SQL password to Key Vault secret
- [ ] Implement key rotation policy
- [ ] Enable Key Vault RBAC (API v2026-02-01+)

**Priority 2: Network Hardening**
- [ ] Create VNet in same region
- [ ] Enable VNet integration for Function App
- [ ] Create private endpoints for SQL, Storage, Key Vault
- [ ] Implement Azure Firewall (if multi-workload)
- [ ] Add WAF to Function App endpoints

**Priority 3: Advanced Monitoring**
- [ ] Deploy Application Insights
- [ ] Enable SQL Database auditing
- [ ] Configure Azure Monitor alerts
- [ ] Implement custom diagnostic logging

**Priority 4: API Security**
- [ ] Implement Azure API Management
- [ ] Enable client certificate authentication
- [ ] Add rate limiting & DDoS protection
- [ ] Integrate Azure AD for user authentication

---

## Compliance Notes

### Data Privacy
✅ **Data Encryption**: All data encrypted at rest and in transit  
✅ **Access Logs**: Activity log tracks all resource access  
⚠️ **Data Residency**: US region; confirm GDPR residency requirements  
❌ **Data Deletion**: No automatic purge; implement retention policy (Phase 2)  

### Industry Standards
✅ **HIPAA Eligible Storage**: Azure Storage with encryption  
✅ **SOC 2 Type II**: Azure PaaS services certified  
⚠️ **ISO 27001**: Applicable; audit trail available  
❌ **HITRUST**: Requires additional controls (Phase 2)  

**Recommendation**: Current MVP suitable for non-sensitive data and internal testing. For production PHI/PII:
1. Implement Phase 2 security hardening
2. Conduct security assessment
3. Obtain compliance certifications
4. Implement data classification

---

## References

- [Azure Security Best Practices](https://learn.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
- [HIPAA/GAAP Compliance Center](https://azure.microsoft.com/en-us/resources/azure-healthcare-compliance/)
- [Bicep Security Linting](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter-rule-details)
- [SQL Database Security](https://learn.microsoft.com/en-us/sql/relational-databases/security/sql-server-security)

---

**Document Status**: ✅ Complete  
**Next Review**: Phase 2 security planning (Q1 2026)  
**Owner**: Security & Infrastructure Team
