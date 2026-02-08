# Pre-Deployment Checklist: Healthcare Call Agent MVP

**Document Version**: 1.0  
**Date Created**: February 8, 2026  
**Scope**: Verification steps before production deployment  
**Use Case**: MVP validation; dev/uat/prod deployments  

---

## Pre-Deployment Acceptance Checklist

### Phase 1: Documentation Review

- [ ] **Specification reviewed** (`specs/001-call-agent-deploy/spec.md`)
  - [ ] All 4 user stories understood
  - [ ] Success criteria clear to team
  - [ ] Risk assessment acknowledged

- [ ] **Architecture reviewed** (`infra/workloads/healthcare-call-agent/CROSS-RG-PATTERN.md`)
  - [ ] Cross-RG pattern understood
  - [ ] RBAC implications reviewed
  - [ ] Shared resource dependencies identified

- [ ] **Cost analysis reviewed** (`specs/001-call-agent-deploy/cost-analysis.md`)
  - [ ] Budget approved (~$122/month total, ~$7/month new)
  - [ ] Cost alerts configured in Azure Cost Management
  - [ ] Phase 2 cost impact understood (+$40-60/month)

- [ ] **Capacity planning reviewed** (`specs/001-call-agent-deploy/capacity-planning.md`)
  - [ ] Resource tiers verified (Consumption, Basic, Standard LRS)
  - [ ] 3-5x headroom confirmed for 100 calls/day
  - [ ] Scaling path understood (when to upgrade tiers)

- [ ] **Security posture reviewed** (`specs/001-call-agent-deploy/security-checklist.md`)
  - [ ] MVP controls understood (encryption, TLS, tagging)
  - [ ] Gaps acknowledged (no Key Vault in MVP)
  - [ ] Phase 2 security roadmap approved

---

### Phase 2: Technical Prerequisites

#### Azure Environment

- [ ] **Azure subscription accessible**
  - [ ] Logged in: `az account show --output table`
  - [ ] Correct subscription selected: `az account set -s {SUBSCRIPTION_ID}`
  - [ ] Subscription quotas sufficient (compute, networking, storage)

- [ ] **Azure CLI installed**
  - [ ] Version 2.60+: `az --version`
  - [ ] Bicep extension available: `az bicep upgrade` (run once)
  - [ ] Verify: `az bicep build --help`

- [ ] **Shared resources verified**
  - [ ] ACS resource exists in `rg-vm-prod-canadacentral-001`
    - [ ] Name documented: _______________
    - [ ] Accessible from function context (public endpoint)
  - [ ] AI Services resource exists in `rg-vm-prod-canadacentral-001`
    - [ ] Name documented: _______________  
    - [ ] Accessible from function context (public endpoint)
  - [ ] Shared RG subscription ID: _______________

#### RBAC & Authentication

- [ ] **Service Principal configured** (for GitHub Actions or CLI)
  - [ ] Client ID documented: _______________
  - [ ] Tenant ID documented: _______________
  - [ ] Subscription ID documented: _______________
  - [ ] Role assignments verified:
    - [ ] Contributor on subscription: `az role assignment list --assignee {SP_ID} | grep Contributor`
    - [ ] Reader on shared RG: `az role assignment list -g rg-vm-prod-canadacentral-001 | grep Reader | grep {SP_ID}`

- [ ] **GitHub Actions secrets configured** (if using CI/CD)
  - [ ] AZURE_CLIENT_ID set
  - [ ] AZURE_TENANT_ID set
  - [ ] AZURE_SUBSCRIPTION_ID set
  - [ ] Environment variables configured for prod (requires manual approval)

#### Parameter Configuration

- [ ] **Parameter files validated**
  - [ ] `environments/dev.bicepparam`
    - [ ] environment = 'dev' ✓
    - [ ] sharedResourceGroupSubscriptionId = correct value
    - [ ] sharedAcsResourceName = correct name
    - [ ] sharedAiServicesResourceName = correct name
    - [ ] sqlAdminPassword set (strong password, minimum 8 chars with uppercase, lowercase, digit, special char)
  
  - [ ] `environments/uat.bicepparam` (if deploying)
    - [ ] environment = 'uat' ✓
    - [ ] All shared resource references verified
    - [ ] SQL password different from dev
  
  - [ ] `environments/prod.bicepparam` (if deploying to production)
    - [ ] environment = 'prod' ✓
    - [ ] All shared resource references verified
    - [ ] SQL password meets compliance requirements
    - [ ] Plan for Phase 2 Key Vault migration documented

#### Bicep Templates

- [ ] **Main template validated**
  - [ ] No syntax errors: `az bicep build --file infra/workloads/healthcare-call-agent/main.bicep --stdout > /dev/null`
  - [ ] Linting rules pass (bicepconfig.json): Check output for no ERRORs
  - [ ] All module references correct: Review module paths in main.bicep

- [ ] **Parameter files validated**
  - [ ] dev.bicepparam: `az bicep build-params --file infra/workloads/healthcare-call-agent/environments/dev.bicepparam`
  - [ ] No ERROR messages (warnings OK)

---

### Phase 3: Deployment Planning

#### Environment Isolation

- [ ] **Deployment target confirmed**
  - [ ] Environment: ☐ dev  ☐ uat  ☐ prod
  - [ ] Region: ☐ eastus2  ☐ other: _______________
  - [ ] Resource Group naming verified: `rg-healthcare-call-agent-{environment}`

- [ ] **No existing resources conflict**
  - [ ] Check for existing RG: `az group exists -n rg-healthcare-call-agent-dev`
  - [ ] If exists, confirm safe to update or delete
  - [ ] Resource naming convention understood (func-*, sql-*, st*, etc.)

#### Testing & Validation

- [ ] **Dev deployment tested locally (if possible)**
  - [ ] What-if analysis run: `az deployment sub what-if --location eastus2 --template-file ... --parameters ...`
  - [ ] Preview shows expected resources (Function App, SQL, Storage, Identity)
  - [ ] No unexpected deletions in what-if output

- [ ] **Cross-RG queries tested** (if possible in test environment)
  - [ ] Manual test: `resourceId()` function can resolve shared resources
  - [ ] Connection strings retrieved from Bicep listKeys()
  - [ ] Test in low-impact environment (dev) first

---

### Phase 4: Deployment Execution

#### Pre-Deployment Checklist

Run these commands to confirm readiness:

```bash
# 1. Authenticate
az login

# 2. Set correct subscription
az account set -s {SUBSCRIPTION_ID}

# 3. Validate Bicep
az bicep build --file infra/workloads/healthcare-call-agent/main.bicep --stdout > /dev/null
echo "✅ Bicep validation passed"

# 4. Validate parameters
az bicep build-params --file infra/workloads/healthcare-call-agent/environments/dev.bicepparam
echo "✅ Parameter validation passed"

# 5. Preview changes (what-if)
az deployment sub what-if \
  --location eastus2 \
  --template-file infra/workloads/healthcare-call-agent/main.bicep \
  --parameters infra/workloads/healthcare-call-agent/environments/dev.bicepparam \
  --output json > what-if-result.json
echo "✅ What-if analysis complete: what-if-result.json"

# 6. Verify RBAC
OBJECT_ID=$(az ad sp show --id {SERVICE_PRINCIPAL_CLIENT_ID} --query id -o tsv)
az role assignment list --assignee $OBJECT_ID | grep Contributor
echo "✅ Contributor role verified"

az role assignment list -g rg-vm-prod-canadacentral-001 | grep Reader | grep $OBJECT_ID
echo "✅ Reader role on shared RG verified"
```

#### Deployment Command (Safe)

```bash
# Command with explicit parameters
az deployment sub create \
  --name "hca-deploy-$(date +%s)" \
  --location eastus2 \
  --template-file infra/workloads/healthcare-call-agent/main.bicep \
  --parameters infra/workloads/healthcare-call-agent/environments/dev.bicepparam

# Expected output:
# - "Deployment succeeded" message
# - List of created resources
# - Output values (Resource Group ID, Function App name, etc.)
```

#### Monitoring Deployment

- [ ] **Deployment progress monitored**
  - [ ] Deployment started and showing "Creating..." status
  - [ ] No immediate error messages
  - [ ] Est. time to completion: ~10-15 minutes

- [ ] **Deployment completed successfully**
  - [ ] Exit code: 0 (success)
  - [ ] Resource Group created: `az group exists -n rg-healthcare-call-agent-dev`
  - [ ] Resources listed: `az resource list -g rg-healthcare-call-agent-dev --output table`

**Deployment Duration Target**: < 10 minutes

---

### Phase 5: Post-Deployment Validation

#### Resource Verification

- [ ] **All resources created**
  - [ ] Storage Account: `az storage account list -g rg-healthcare-call-agent-dev --output table`
  - [ ] SQL Server & Database: `az sql server list -g rg-healthcare-call-agent-dev --output table`
  - [ ] User-Assigned Identity: `az identity list -g rg-healthcare-call-agent-dev --output table`
  - [ ] Function App: `az functionapp list -g rg-healthcare-call-agent-dev --output table`
  - [ ] App Service Plan: `az appservice plan list -g rg-healthcare-call-agent-dev --output table`

- [ ] **Resource naming verified**
  - [ ] Storage Account name starts with 'sthc' (must be < 24 chars, globally unique)
  - [ ] SQL Server: 'sql-healthcare-call-agent-{env}'
  - [ ] Database: 'db-calls-{env}'
  - [ ] Function App: 'func-healthcare-call-agent-{env}'
  - [ ] Identity: 'id-healthcare-call-agent-{env}'

#### Configuration Verification

- [ ] **Function App settings verified**
  ```bash
  az functionapp config appsettings list \
    -g rg-healthcare-call-agent-dev \
    -n func-healthcare-call-agent-dev
  ```
  - [ ] ACS_CONNECTION_STRING present and non-empty
  - [ ] ACS_RESOURCE_ID present
  - [ ] AI_SERVICES_ENDPOINT present and valid URL
  - [ ] AI_SERVICES_KEY present (masked in output, but value exists)
  - [ ] SQL_CONNECTION_STRING present (with correct server name)
  - [ ] ENVIRONMENT = 'dev'

- [ ] **Tags applied to all resources**
  ```bash
  az resource list \
    -g rg-healthcare-call-agent-dev \
    --query "[].tags"
  ```
  - [ ] workload: 'healthcare-call-agent'
  - [ ] environment: 'dev'
  - [ ] managedBy: 'IaC'
  - [ ] createdDate: '[Date]'

#### Connectivity Tests

- [ ] **SQL Database connectivity**
  ```bash
  # From Azure Cloud Shell (has access to Azure services)
  sqlcmd -S sql-healthcare-call-agent-dev.database.windows.net \
    -U sqladmin \
    -P '{PASSWORD}' \
    -d db-calls-dev \
    -Q "SELECT @@VERSION"
  ```
  - [ ] Successfully connects
  - [ ] Database 'db-calls-dev' accessible
  - [ ] Query returns SQL Server version

- [ ] **Cross-RG resource queries**
  ```bash
  # Verify shared resources still accessible
  az resource show \
    -g rg-vm-prod-canadacentral-001 \
    --name {SHARED_ACS_NAME} \
    --resource-type Microsoft.Communication/communicationServices
  ```
  - [ ] ACS resource found
  - [ ] Properties returned (dataLocation, etc.)

#### Function App Health

- [ ] **Function App is running**
  ```bash
  az functionapp show \
    -g rg-healthcare-call-agent-dev \
    -n func-healthcare-call-agent-dev \
    --query "state"
  ```
  - [ ] State: 'Running' ✓

- [ ] **HTTP endpoint accessible**
  ```bash
  HOSTNAME=$(az functionapp show \
    -g rg-healthcare-call-agent-dev \
    -n func-healthcare-call-agent-dev \
    --query "defaultHostName" -o tsv)
  
  curl -I https://${HOSTNAME}/api/health
  ```
  - [ ] HTTP 200-302 response (not 503/500)
  - [ ] Endpoint accessible over HTTPS

#### Cost & Budget

- [ ] **Initial resources appear in billing**
  - [ ] Azure Cost Management updated (may take 24-48 hours)
  - [ ] Budget alert configured: `$ 15/month threshold` (125% of $12 target)
  - [ ] Notification email configured: _______________

---

### Phase 6: Post-Deployment Handoff

#### Documentation

- [ ] **Deployment documented in team wiki/docs**
  - [ ] Deployment date: _______________
  - [ ] Environment: ☐ dev  ☐ uat  ☐ prod
  - [ ] Deployer name: _______________
  - [ ] Deployment ID (from az output): _______________
  - [ ] Resource Group URI: `rg-healthcare-call-agent-{env}`

- [ ] **Known issues documented**
  - [ ] Cold start behavior noted (first request ~5 seconds)
  - [ ] Any RBAC misconfigurations documented for Phase 2 fix
  - [ ] SQL password rotation plan documented (Phase 2 → Key Vault)

#### Operational Handoff

- [ ] **Ops team briefed**
  - [ ] Deployment process explained (Bicep → az deployment sub create)
  - [ ] Troubleshooting guide reviewed (`specs/001-call-agent-deploy/troubleshooting.md`)
  - [ ] Monitoring/alerting configured
  - [ ] Escalation contact established: _______________

- [ ] **Support documentation**
  - [ ] DEPLOYMENT-NOTES.md provided to ops
  - [ ] CROSS-RG-PATTERN.md provided to engineers
  - [ ] Cost analysis provided to finance: _______________
  - [ ] Security checklist provided to compliance: _______________

---

## Deployment Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Infrastructure Lead** |  |  |  |
| **Security Review** |  |  |  |
| **Operations Approval** |  |  |  |
| **Finance Approval** |  |  |  |

---

## Deployment Rollback Plan

**If deployment fails or critical issues found:**

1. **Stop further changes**
   - Halt any post-deployment modifications
   - Notify team of issue status

2. **Assess impact**
   - Are other workloads affected? (cross-RG)
   - Is shared resource group affected?
   - How many users impacted?

3. **Rollback steps**
   ```bash
   # Option A: Delete and redeploy (safest for dev/uat)
   az group delete -n rg-healthcare-call-agent-dev --yes
   
   # Option B: Update existing deployment (if safe)
   # Modify Bicep, set back to previous state, redeploy
   az deployment sub create \
     --location eastus2 \
     --template-file infra/workloads/healthcare-call-agent/main.bicep \
     --parameters infra/workloads/healthcare-call-agent/environments/dev.bicepparam
   ```

4. **Post-rollback validation**
   - Verify shared resources still functional
   - Confirm no orphaned resources left behind
   - Update status to team

---

**Document Status**: ✅ Complete  
**Last Updated**: February 8, 2026  
**Owner**: Infrastructure & DevOps Team  
**Next Use**: [Date of next deployment]
