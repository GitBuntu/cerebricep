# AuthPilot Deployment Tasks Checklist

## Phase 1: Infrastructure Planning & Setup ✅ COMPLETED

- [x] Define Azure Architecture
  - [x] Document resource naming conventions
  - [x] Identify resource group strategy (single RG per dev environment)
  - [x] Plan RBAC and managed identity permissions
  - [x] Map configuration values to Key Vault vs App Configuration

- [x] Create Bicep Parameter Files
  - [x] Create `authpilot-dev.bicepparam` (free-tier config)

- [x] Configure Free-Tier Parameters
  - [x] Cosmos DB: 100 RU/s, 25 GB storage
  - [x] Blob Storage: 5 GB/month allocation, standard LRS
  - [x] Document Intelligence: Monitor free tier (500 transactions/month)
  - [x] Functions: Consumption plan Y1 (free for ~1M executions/month)
  - [x] Key Vault: Standard tier (free)
  - [x] Application Insights: Free tier (1 GB/month)

---

## Phase 2: Code Updates for Cosmos DB ✅ PARTIALLY COMPLETED

- [x] Update AuthPilot Function Configuration
  - [x] Update `D:\source\authpilot\src\local.settings.json` with Cosmos DB connection string format
  - [x] Add Key Vault URI and Managed Identity Client ID configuration
  - [ ] Implement environment variable injection from Key Vault (helper class needed)
  - [ ] Add connection validation in `MongoDbService` constructor
  - [ ] Test MongoDB driver compatibility (verify existing driver works)

- [x] Configure MongoDB Connection String
  - [x] Format: `mongodb://{account}:{password}@{account}.mongo.cosmos.azure.com:10255/?ssl=true&retrywrites=false&maxIdleTimeMS=120000`
  - [x] Update local.settings.json with placeholder values and Cosmos DB format
  - [x] Add documentation for connection string generation (commented templates in local.settings.json)
  - [ ] Document how to retrieve Cosmos DB credentials from Azure Portal

---

## Phase 3: GitHub Actions Setup ✅ COMPLETED

- [x] Configure OIDC Authentication for Azure
  - [x] Create Azure AD service principal with Contributor role
  - [x] Register Federated Identity Credential in Azure AD (GitHub → Azure trust)
  - [x] Set GitHub repository secrets:
    - [x] `AZURE_CLIENT_ID` (from setup-oidc.sh output)
    - [x] `AZURE_TENANT_ID` (from setup-oidc.sh output)
    - [x] `AZURE_SUBSCRIPTION_ID` (from setup-oidc.sh output)
    - [x] `AZURE_REGION` (eastus2)
  - [x] Create GitHub Environment: `development` (optional)

- [x] Create/Update GitHub Actions Workflow
  - [x] Workflow file: `.github/workflows/deploy-authpilot.yml` ✅ COMPLETED
  - [x] Validate Bicep templates
  - [x] Authenticate to Azure via OIDC
  - [x] Deploy infrastructure (dev only)
  - [x] Store deployment outputs as artifacts

- [x] Create Deployment Automation Scripts
  - [x] `scripts/setup-oidc.sh` — Complete OIDC setup (idempotent)
  - [x] `scripts/create-resource-group.sh` — Resource group creation (idempotent)

---

## Phase 4: Deployment & Validation

- [ ] Verify Naming Conventions
  - [ ] Review resource names against [Azure Resource Namer tool](https://flcdrg.github.io/azure-resource-namer/) and [CAF naming guide](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
  - [x] Pattern: `<type>-<workload>-<environment>-<region>-<instance>`
  - [x] Function App: `func-authpilot-dev-eastus-001` ✅
  - [x] App Service Plan: `asp-authpilot-dev-eastus-001` ✅
  - [x] Cosmos DB: `cosmos-authpilot-dev-eastus-001` ✅
  - [x] Key Vault: `kv-authpilot-dev-eastus-001` ✅
  - [x] Storage Account: `stauthorpilotdeveustus001` ✅
  - [x] Resource Group: `rg-authpilot-dev-eastus-001` ✅
  - [x] App Insights: `appi-authpilot-dev-eastus-001` ✅
  - [x] Managed Identity: `id-authpilot-dev-eastus-001` ✅
  - [x] Log Analytics: `log-authpilot-dev-eastus-001` ✅
  - [x] Virtual Network: `vnet-authpilot-dev-eastus-001` ✅

- [x] Pre-Deployment Checks
  - [x] Create resource group: `rg-authpilot-dev-eastus-001`
  - [x] Verify GitHub secrets are correctly configured
  - [x] Verify branch protection rules allow GitHub Actions - NA for dev
  - [x] Test Bicep templates locally: `az bicep build --file infra/main.bicep`

- [ ] Deploy Infrastructure via GitHub Actions
  - [ ] Push changes to dev branch (triggers workflow)
  - [ ] Verify GitHub Actions workflow runs successfully
  - [ ] Check workflow logs for Bicep validation errors
  - [ ] Verify resource creation in Azure Portal:
    - [ ] Resource group `rg-authpilot-dev-eastus-001` exists
    - [ ] Function App `func-authpilot-dev-eastus-001` created
    - [ ] Storage Account `st{workloadname}deveastus001` created
    - [ ] Cosmos DB `cosmos-authpilot-dev-eastus-001` created
    - [ ] Key Vault `kv-authpilot-dev-eastus-001` created
    - [ ] Application Insights `appi-authpilot-dev-eastus-001` created
  - [ ] Confirm RBAC permissions are applied
  - [ ] Verify managed identity has Key Vault access

- [ ] Configure Key Vault Secrets
  - [ ] Add `cosmos-db-connection-string` secret
  - [ ] Add `document-intelligence-api-key` secret
  - [ ] Add `document-intelligence-endpoint` secret
  - [ ] Add `blob-storage-connection-string` secret (optional backup)
  - [ ] Verify Function App managed identity can read secrets

- [ ] Deploy AuthPilot Function Code
  - [ ] Build C# Function project: `dotnet publish -c Release`
  - [ ] Deploy Function App code via GitHub Actions or Azure CLI
  - [ ] Verify function logs show successful startup
  - [ ] Check Application Insights for function metrics
  - [ ] Confirm managed identity is authenticated (no auth errors)

---

## Phase 5: End-to-End Testing

- [ ] Functional Testing
  - [ ] Upload test fax to Blob Storage (use Azure Storage Explorer)
  - [ ] Verify Function App blob trigger fires
  - [ ] Check Application Insights logs show function execution
  - [ ] Query Cosmos DB to verify document creation: `db.authorizations.find()`
  - [ ] Validate Document Intelligence extracted fields correctly
  - [ ] Confirm status transitions: `processing` → `completed`
  - [ ] Verify timestamps recorded correctly

- [ ] Error Scenario Testing
  - [ ] Test with corrupted/invalid fax file
  - [ ] Test with oversized file
  - [ ] Test Cosmos DB throttling behavior (100 RU/s limit)
  - [ ] Verify error logging to Application Insights
  - [ ] Confirm error handling doesn't break pipeline

- [ ] Cost & Performance Monitoring
  - [ ] Monitor Document Intelligence usage (free tier: 500/month)
  - [ ] Monitor Cosmos DB RU consumption (free tier: 100 RU/s)
  - [ ] Monitor Function App execution time (target: < 30 seconds)
  - [ ] Monitor storage costs (5 GB/month free)
  - [ ] Set up billing alerts if needed

---

## Documentation

- [ ] Create Deployment Runbook
  - [ ] Document steps to deploy to dev environment
  - [ ] Include troubleshooting section
  - [ ] Document how to retrieve credentials from Azure Portal
  - [ ] Include monitoring and alert setup

- [ ] Update README
  - [ ] Add deployment instructions
  - [ ] Document free tier limits and costs
  - [ ] Add architecture diagram
  - [ ] Include security considerations

- [ ] Document Configuration
  - [ ] Document all environment variables required
  - [ ] Document connection string format for Cosmos DB
  - [ ] Document Key Vault secret naming convention
  - [ ] Document OIDC federated identity setup

---

## Success Criteria Validation

- [ ] All Bicep templates validate without errors
- [ ] Resources deploy to Azure successfully
- [ ] Function App successfully connects to Cosmos DB
- [ ] Blob trigger fires when fax is uploaded
- [ ] Document Intelligence extracts authorization fields correctly
- [ ] MongoDB documents transition from `processing` → `completed` status
- [ ] No publicly exposed endpoints (everything internal/secured)
- [ ] All secrets stored in Key Vault (no hardcoded credentials)
- [ ] Function logs visible in Application Insights
- [ ] End-to-end processing completes in < 30 seconds

---

## Notes & Blockers

- **OIDC Setup**: Requires Azure AD access and GitHub org access
- **Free Tier Limits**: Monitor Document Intelligence (500/month) and Cosmos DB (100 RU/s)
- **Resource Group**: Must be created before Bicep deployment (or create in template)
- **Managed Identity**: Must be deployed before other resources can reference it

---

**Last Updated**: December 14, 2025
