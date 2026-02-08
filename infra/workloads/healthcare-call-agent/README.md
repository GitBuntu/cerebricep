# Healthcare Call Agent MVP - Deployment Guide

## Manual Setup Required

Before deploying via GitHub Actions, complete the following manual steps:

### 1. GitHub Secrets Configuration (REQUIRED FOR GITHUB ACTIONS)

Configure GitHub environment secrets for each deployment environment (dev, uat, prod):

**Steps:**
1. Go to repository → Settings → Environments
2. Create environments (if missing): `dev`, `uat`, `prod`
3. For each environment, add these secrets:
   - `AZURE_CLIENT_ID` - From Azure OIDC app registration
   - `AZURE_TENANT_ID` - From Azure OIDC app registration
   - `AZURE_SUBSCRIPTION_ID` - Your Azure subscription ID

**Retrieve your subscription ID:**
```bash
az account show --query id -o tsv
```

**Without these secrets, GitHub Actions deployments will fail at the Azure Login step.**

### 2. Parameter File Configuration (LOCAL ONLY)

Parameter files (`environments/*.bicepparam`) require local configuration before deployment. **Do not commit credentials.**

⚠️ **WARNING:** Deployment will FAIL if you try to use empty parameter values. You MUST provide actual values for:
- `sqlAdminPassword` 
- `sharedResourceGroupSubscriptionId`

**Required parameters to populate locally:**

1. **Subscription ID** - Set `sharedResourceGroupSubscriptionId`:
   ```bash
   az account show --query id -o tsv
   ```

2. **SQL Admin Password** - Set `sqlAdminPassword` to a strong password:
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - **Phase 2:** Migrate to Key Vault (remove plaintext password)

**Option A: Edit parameter file locally (dev only)**
```bash
# Edit infra/workloads/healthcare-call-agent/environments/dev.bicepparam
param sharedResourceGroupSubscriptionId = '<your-subscription-id>'
param sqlAdminPassword = '<your-strong-password>'
```

**Option B: Override parameters at deploy time (all environments)**
```bash
az deployment sub create \
  --name hca-deploy-$(date +%s) \
  --location westus \
  --template-file infra/workloads/healthcare-call-agent/main.bicep \
  --parameters infra/workloads/healthcare-call-agent/environments/uat.bicepparam \
  --parameters sharedResourceGroupSubscriptionId='{YOUR_SUBSCRIPTION_ID}' \
  --parameters sqlAdminPassword='{YOUR_STRONG_PASSWORD}'
```

**Keep these files out of version control:** Parameter files are in `.gitignore`; they won't be committed to Git.

### 3. Local Testing Before GitHub Deployment (OPTIONAL BUT RECOMMENDED)

**First:** Populate `environments/dev.bicepparam` with your subscription ID and SQL password (see section 2 above).

Then test the deployment locally:

```bash
# Validate
az bicep build --file infra/workloads/healthcare-call-agent/main.bicep --verbose
az bicep build-params --file infra/workloads/healthcare-call-agent/environments/dev.bicepparam --verbose

# Preview changes
az deployment sub what-if \
  --location westus \
  --template-file infra/workloads/healthcare-call-agent/main.bicep \
  --parameters infra/workloads/healthcare-call-agent/environments/dev.bicepparam

# Deploy
az deployment sub create \
  --name hca-deploy-$(date +%s) \
  --location westus \
  --template-file infra/workloads/healthcare-call-agent/main.bicep \
  --parameters infra/workloads/healthcare-call-agent/environments/dev.bicepparam \
  --verbose 2>&1 | tee deployment.log
```

## Deployment Architecture

### Environments

| Environment | Location  | SKU      | Notes                          |
|-------------|-----------|----------|--------------------------------|
| dev         | westus    | Flex     | Quota-free, auto-deploys from main branch |
| uat         | eastus2   | S1       | Standard tier, manual approval |
| prod        | eastus2   | P1v2     | Premium tier, manual approval  |

### Resources Created

- **7 core resources per environment:**
  - Managed Identity (User-Assigned)
  - App Service Plan
  - Function App (dotnet-isolated 9.0)
  - Storage Account (deployment + blob storage)
  - SQL Server
  - SQL Database (master + calls)
  - Event Grid (messaging)

### Cross-RG Resource References

Function App integrates with shared resources in `rg-vm-prod-canadacentral-001`:
- **Azure Communication Services (ACS):** `callistra-test`
- **AI Services (Speech):** `callistra-speech-services`

These are read-only references; no changes to shared RG needed.

## GitHub Actions Workflow

**Trigger:** Push to `main` in `infra/workloads/healthcare-call-agent/` directory

**Pipeline stages:**
1. **Validate** - Build Bicep, check linting
2. **What-If** - Preview resource changes
3. **Deploy** - Create/update infrastructure
4. **Post-Validate** - Verify all resources created
5. **Cost Monitoring** - Alert setup (manual budget config in Azure Portal)

**Manual deployments:** Use workflow_dispatch to deploy to specific environment with manual approval for uat/prod.

## Troubleshooting

### Deployment fails with timeout (exit 130)
- **This is expected.** Deployment continues in background.
- Wait 60 seconds, then verify: `az resource list -g rg-healthcare-call-agent-{env} -o table`
- If resources exist, deployment succeeded despite timeout message.

### What-If shows quota errors
- **ElasticPremium or Y1 Consumption quota not available**
- Solution: Use Flex plan (already configured for dev)
- For uat/prod: Request quota increase in Azure Portal (Subscriptions → Usage + quotas)

### Parameter validation fails
- **Check bicepparam files contain actual values, not placeholders**
- Example: Subscription ID should be `{YOUR_SUBSCRIPTION_ID}`, not a literal value

### GitHub Actions: Can't authenticate to Azure
- **GitHub secrets not configured**
- Fix: Complete "GitHub Secrets Configuration" section above
- Verify secrets exist in repository Settings → Environments

## Next Steps (Phase 2)

These items are out of scope for MVP:
- [ ] Migrate SQL passwords from bicepparam to Key Vault
- [ ] Deploy Application Insights for monitoring
- [ ] Deploy Key Vault for secret management
- [ ] Deploy App Configuration for environment settings
- [ ] Configure RBAC for cross-RG service principal access
- [ ] Add Function App code deployment pipeline

## Important Notes

- **RG Idempotency:** If a single resource fails, keep the RG and redeploy (fix the template first). Do not delete the RG.
- **API Versions:** All resources use stable GA API versions (no preview APIs).
- **Flex Consumption:** Dev environment uses quota-free Flex plan; uat/prod use traditional App Service plans.
- **Region Immutability:** RG location cannot be changed after creation. Changing regions requires a new RG.
