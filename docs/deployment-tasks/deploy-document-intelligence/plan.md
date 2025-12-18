# AuthPilot Deployment Plan - Free Azure Services

## Plan Summary
Deploy the AuthPilot fax processing pipeline to Azure using free-tier services (Blob Storage, Cosmos DB, Functions, Document Intelligence) with secure internal communication via managed identities and no public exposure.

## Steps

### Phase 1: Infrastructure Planning & Setup
1. **Define Azure Architecture**
   - Document resource naming conventions (follow cerebricep naming: `{type}-authpilot-{env}`)
   - Identify resource group strategy (single RG per environment: dev)
   - Plan RBAC and managed identity permissions
   - Map configuration values to Key Vault vs App Configuration

2. **Create Bicep Module Templates**
   - Create new workload: `infra/workloads/authpilot/` (or extend existing modules)
   - Develop modules for AuthPilot-specific resources:
     - `modules/ai/document-intelligence.bicep` (update existing if needed)
     - Reuse existing: `modules/data/cosmos-db.bicep`, `modules/data/storage-account.bicep`, `modules/compute/function-app.bicep`
   - Update `main.bicep` to support authpilot workload parameter
   - Create environment files: `authpilot-dev.bicepparam`,

3. **Configure Free-Tier Parameters**
   - **Cosmos DB**: 100 RU/s, 25 GB storage (dev)
   - **Blob Storage**: 5 GB/month allocation, standard LRS
   - **Document Intelligence**: Monitor free tier limit (500 transactions/month = ~16 faxes/day)
   - **Functions**: Consumption plan (pay-per-execution, free for ~1M/month)
   - **Key Vault**: Standard tier (free)
   - **Application Insights**: Free tier (1 GB/month ingestion)

### Phase 2: Code Updates for Cosmos DB
4. **Update AuthPilot Function Configuration**
   - Update `local.settings.json` with Cosmos DB connection string format
   - Implement environment variable injection from Key Vault
   - Add connection validation in `MongoDbService` constructor
   - Test MongoDB driver compatibility (already uses correct driver)

5. **Configure MongoDB Connection String**
   - Format: `mongodb://{account}:{password}@{account}.mongo.cosmos.azure.com:10255/?ssl=true&retrywrites=false&maxIdleTimeMS=120000`
   - Store credentials securely in Key Vault
   - Function App retrieves via managed identity (no hardcoded secrets)

### Phase 3: Security & Identity Configuration
6. **Set Up Managed Identity & Key Vault RBAC**
   - Create user-assigned managed identity for Function App
   - Grant permissions:
     - **Key Vault**: Read secrets (connection strings, API keys)
     - **Blob Storage**: Read blob data + list containers
     - **Cosmos DB**: Database account read/write (via connection string)
     - **Document Intelligence**: API key (stored in Key Vault, retrieved via managed identity)
   - Store secrets:
     - `cosmos-db-connection-string`
     - `document-intelligence-api-key`
     - `document-intelligence-endpoint`
     - `blob-storage-connection-string`

7. **Configure Function App Settings**
   - Set Key Vault URI in Function App environment variables
   - Configure Managed Identity client ID
   - Function reads configuration from Key Vault at runtime
   - Verify blob trigger configuration points to correct container
   - Set MongoDB and Document Intelligence model ID parameters

### Phase 4: GitHub Actions Workflow Setup
8. **Configure OIDC Authentication for Azure**
   - Register Federated Identity Credentials in Azure AD (no stored secrets)
   - Configure GitHub environment variables:
     - `AZURE_CLIENT_ID` - Service principal client ID
     - `AZURE_TENANT_ID` - Azure AD tenant ID
     - `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
     - `AZURE_REGION` - Deployment region (e.g., `eastus`)
   - Create GitHub Environments: `development`, `staging`, `production`

9. **Create/Update GitHub Actions Workflow**
   - Workflow file: `.github/workflows/deploy-authpilot.yml`
   - Steps:
     1. Trigger: `push` to main branch (dev)
     2. Checkout code from cerebricep repo
     3. Validate Bicep: `az bicep build --file infra/main.bicep --stdout > /dev/null`
     4. Authenticate to Azure via OIDC (no credentials in secrets)
     5. Deploy infrastructure: `az deployment group create --template-file infra/main.bicep --parameters infra/environments/{env}.bicepparam`
     6. Deploy Function App code: `func azure functionapp publish func-authpilot-{env}`
   - Matrix strategy for dev environments
   - Add concurrency lock to prevent simultaneous deployments
   - Include rollback script if deployment fails

### Phase 5: Deployment & Validation
10. **Deploy Infrastructure via GitHub Actions**
    - Push changes to main branch (triggers dev deployment automatically)
    - Verify GitHub Actions workflow runs successfully
    - Check workflow logs for any Bicep validation errors
    - Verify resource creation in Azure Portal (resource group, RBAC, Key Vault)
    - Confirm RBAC permissions are applied correctly

11. **Deploy AuthPilot Function Code**
    - GitHub Actions automatically builds and deploys Function App code
    - Verify function logs show successful startup: `func azure functionapp log stream func-authpilot-dev`
    - Check Application Insights for function metrics
    - Confirm managed identity is authenticated (no connection errors)

12. **End-to-End Testing**
    - Upload test fax to Blob Storage (use Azure Storage Explorer)
    - Verify Function App blob trigger fires (check Application Insights)
    - Query Cosmos DB to verify document creation: `db.authorizations.find()`
    - Validate Document Intelligence extracted fields correctly
    - Confirm status transitions: `processing` → `completed` → `completed`
    - Test error scenarios (corrupted file, timeout, quota exceeded)
    - Monitor cost impact of free tier usage

## Risks

### High Impact
- **Free Tier Document Intelligence Limit (500/month)**
  - *Risk*: Production usage may exceed free tier quickly (500 = ~16 faxes/day)
  - *Mitigation*: Monitor usage in Azure Portal; set up alerts; budget for overage costs if volume increases
  - *Action*: Document acceptable volume limits in README

- **Cosmos DB Throttling (100 RU/s)**
  - *Risk*: Peak loads may exceed 100 RU/s, causing 429 rate-limit errors
  - *Mitigation*: Implement retry logic with exponential backoff (not in current MVP); design for burst handling
  - *Action*: Start with dev environment to establish baseline RU consumption

- **Function App Cold Starts**
  - *Risk*: Consumption plan Function may have 10-30s cold start, delaying fax processing
  - *Mitigation*: Accept latency for MVP; add "warm-up" trigger if production needs sub-second response
  - *Action*: Document expected latency in deployment guide

### Medium Impact
- **Managed Identity Authentication in Local Development**
  - *Risk*: Function works in Azure but fails locally without managed identity
  - *Mitigation*: Use connection strings in `local.settings.json` for local dev; use managed identity for Azure
  - *Action*: Document setup instructions for both local and cloud scenarios

- **Cosmos DB Schema Mismatch**
  - *Risk*: Existing MongoDB code may have incompatibilities with Cosmos DB's MongoDB API
  - *Mitigation*: Test with sample data before production; verify indexes work correctly
  - *Action*: Run integration tests in dev environment; document any Cosmos DB-specific behavior

- **Document Intelligence Model ID Configuration**
  - *Risk*: Custom model ID must be manually configured; wrong ID = extraction failures
  - *Mitigation*: Store model ID in Key Vault; document how to find it in Azure Portal
  - *Action*: Add setup script to retrieve and configure model ID

### Low Impact
- **Bicep Module Reusability**
  - *Risk*: AuthPilot resources may not fit existing module structure perfectly
  - *Mitigation*: Extend modules as needed; maintain modularity for future workloads
  - *Action*: Review existing modules before creating new ones

- **GitHub Actions Secrets Management**
  - *Risk*: Storing sensitive values in GitHub Actions secrets creates exposure
  - *Mitigation*: Use OIDC federated identity (no secrets stored); all credentials in Key Vault
  - *Action*: Never commit connection strings or API keys; rely on managed identity + Key Vault

- **Workflow Trigger Issues**
  - *Risk*: Workflow may not trigger on push if branch protection rules conflict
  - *Mitigation*: Configure branch protection to allow GitHub Actions deployment
  - *Action*: Document branch protection settings required for CI/CD

- **GitHub Environment Approval Delays**
  - *Risk*: Manual approval for uat/prod may delay urgent deployments
  - *Mitigation*: Define SLAs for approvals; document approval process
  - *Action*: Assign approvers and document escalation contacts

- **OIDC Token Expiration**
  - *Risk*: Long-running GitHub Actions jobs may exceed OIDC token lifetime (15 min)
  - *Mitigation*: Structure workflow to complete within token lifetime; re-authenticate if needed
  - *Action*: Monitor workflow duration; split if exceeds 10 minutes

## GitHub Actions Deployment Requirements

### Prerequisites
- **Azure AD Service Principal** with Contributor role on subscription
- **Federated Identity Credential** configured in Azure AD (for OIDC)
- **GitHub Repository Secrets** configured (NEVER store credentials):
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
  - `AZURE_REGION` (e.g., `eastus`)
- **GitHub Environments** created: `development`, `staging`, `production`
- **Branch Protection Rules**: Require PR reviews before merge to main

### Deployment Flow
```
1. Developer pushes code to feature branch
   ↓
2. GitHub Actions validates Bicep + runs tests
   ↓
3. Developer creates PR to main
   ↓
4. PR approved and merged to main
   ↓
5. GitHub Actions triggers deployment workflow
   ↓
6. Authenticate to Azure via OIDC (no secrets)
   ↓
7. Validate Bicep templates
   ↓
8. Deploy infrastructure (dev auto-deploy)
   ↓
9. Deploy to approved environment
   ↓
10. Deploy Function App code
   ↓
11. Verify deployment in Azure Portal
```

---

1. **Environment Strategy**: Should AuthPilot use separate dev/uat/prod subscriptions, or single subscription with resource groups?
   - *Recommendation*: Single subscription, separate resource groups (simpler for free tier)

2. **Blob Upload Method**: How will faxes be uploaded to Blob Storage? (Azure Storage Explorer, SAS token, custom UI?)
   - *Recommendation*: Document multiple options; recommend SAS tokens for external users

3. **Monitoring & Alerting**: Should AlertPilot use Application Insights + Log Analytics, or just Function App logs?
   - *Recommendation*: Use free tier Application Insights for basic monitoring; add alerts for errors

4. **Data Retention**: How long should processed authorizations be kept in Cosmos DB?
   - *Recommendation*: Define TTL policy in Cosmos DB to manage storage costs

5. **Scaling Strategy**: What's the plan if Document Intelligence free tier is exceeded?
   - *Recommendation*: Budget for S0 paid tier (~$40/month for 5K transactions); monitor usage proactively

---

## Success Criteria

✅ All Bicep templates validate without errors
✅ Resources deploy to Azure successfully (dev environment)
✅ Function App successfully connects to Cosmos DB via managed identity
✅ Blob trigger fires when fax is uploaded
✅ Document Intelligence extracts authorization fields correctly
✅ MongoDB documents transition from `processing` → `completed` status
✅ No publicly exposed endpoints (everything internal/secured)
✅ All secrets stored in Key Vault (no hardcoded credentials)
✅ Function logs are visible in Application Insights
✅ End-to-end processing completes in < 30 seconds (acceptable latency for MVP)

## Timeline Estimate

- **Phase 1 (Infrastructure)**: 2-3 hours
  - Bicep template creation and design
  - Parameter file setup
  - RBAC planning
  - GitHub environment configuration

- **Phase 4 (GitHub Actions)**: 1-2 hours
  - OIDC federated identity setup
  - GitHub Actions workflow creation
  - Environment configuration

- **Phase 5 (Deployment & Testing)**: 2-3 hours
  - Infrastructure deployment via GitHub Actions
  - Function code deployment
  - End-to-end testing and troubleshooting

**Total Estimate: 6-9 hours (MVP scope, GitHub Actions only)**

---

## Next Steps

1. ✅ Approve plan and clarify questions
2. Create Bicep modules (start with cosmos-db.bicep update)
3. Update authpilot code for Cosmos DB connection
4. Deploy to dev environment
5. Execute end-to-end testing
6. Document results and create deployment runbook
