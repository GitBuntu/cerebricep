# Copilot Instructions for `cerebricep`

## 1. Repository Overview

- **Language**: Bicep (Azure ARM template DSL)
- **Deployment**: Azure subscription-scope with Azure CLI + GitHub Actions
- **Architecture**: Workload-centric (independent, no cross-workload dependencies)
- **Goal**: Infrastructure-as-Code with repeatable, version-controlled deployments

## 2. Project Structure

```
infra/
├── modules/              # Reusable building blocks (scoped to resource group)
│   ├── ai/               # Document Intelligence, Cognitive Services
│   ├── compute/          # Function App, App Service Plan
│   ├── config/           # Key Vault, App Configuration
│   ├── data/             # Cosmos DB, DocumentDB, Storage Account, SQL
│   ├── identity/         # User-Assigned Managed Identity
│   ├── messaging/        # Event Grid
│   └── monitoring/       # Log Analytics, Application Insights, Actions
└── workloads/
    ├── authpilot/        # Self-contained workload (subscription-scope main.bicep)
    └── {workload-name}/
        ├── main.bicep    # Orchestration template (creates RG + deploys modules)
        ├── DEPLOYMENT-NOTES.md
        └── environments/
            ├── dev.bicepparam
            ├── uat.bicepparam
            └── prod.bicepparam
```

### Core Principles
- **Each workload is independent**: Its own main.bicep + parameter files
- **Module scope**: Resource Group (not subscription scope)
- **Module design**: Standalone, accept (location, tags, resource params), output (IDs, endpoints, principal IDs)
- **No scripts**: Everything in Bicep templates
- **No hardcoded values**: All parameters in .bicepparam files

### Current Workloads
- **AuthPilot**: `infra/workloads/authpilot/` — Fax processing with DocumentDB (MongoDB)

## 3. Mandatory Pre-Deployment Validation Pipeline

**REQUIRED SEQUENCE (never skip, never reorder):**

### Step 1: Build Validation
```bash
az bicep build --file infra/workloads/{workload}/main.bicep --verbose
az bicep build-params --file infra/workloads/{workload}/environments/{env}.bicepparam --verbose
```
- **Expected**: No errors (linting warnings OK)
- **Why mandatory**: Catches syntax errors, missing modules, resource conflicts before deployment

### Step 2: Dry-Run Analysis (what-if)
```bash
az deployment sub what-if \
  --location {region} \
  --template-file infra/workloads/{workload}/main.bicep \
  --parameters infra/workloads/{workload}/environments/{env}.bicepparam 2>&1 | grep -i "create\|modify\|delete\|quota\|error"
```
- **Expected**: Shows resources to create/modify, no quota errors
- **Why mandatory**: Reveals quota limits, permission issues, parameter mismatches BEFORE actual deployment

### Step 3: Deployment
```bash
az deployment sub create \
  --name {workload}-{env}-$(date +%s) \
  --location {region} \
  --template-file infra/workloads/{workload}/main.bicep \
  --parameters infra/workloads/{workload}/environments/{env}.bicepparam \
  --verbose 2>&1 | tee deployment.log
```
- **Expected**: `"provisioningState": "Succeeded"`
- **If timeout appears**: IGNORE. Deployment continues in background. Wait 60 sec, then verify: `az resource list -g rg-{workload}-{env} -o table`

### Step 4: Verification
```bash
az resource list -g rg-{workload}-{env} --query "[].{Name:name, Type:type}" -o table
```
- **Expected**: All resources present
- **Why**: Confirms nothing was skipped, dependencies resolved



## 4. Critical Lessons from Healthcare Call Agent Deployment (Feb 2026)

### Module Parameter Chain Validation
- **Rule**: Every parameter passed to a module at call site must be defined in module's @param
- **Audit Finding**: Function App module had `isFlex` logic but never received `sku` parameter value
- **Prevention**: After updating module, verify ALL parameters are satisfied at all call sites
- **Check**: `az bicep build --file main.bicep --verbose` catches undefined params before deployment

### API Version Compatibility by Region
- **Rule**: Never use preview API versions (e.g., `@2024-01-01-preview`) without regional verification
- **Audit Finding**: CommunicationServices `@2024-03-31` not registered globally; SQL `@2024-01-01-preview` unavailable in westus
- **Prevention**: Use stable GA versions only (e.g., `@2023-08-01`, `@2023-04-01`)
- **Discovery**: Read Azure error message for supported API versions; test with `what-if` before deployment

### Identity Type Property Matching
- **Rule**: Output properties must match identity type (SystemAssigned vs UserAssigned)
- **Audit Finding**: Function App outputs tried to read `principalId` from UserAssigned identity (doesn't exist)
- **UserAssigned properties**: `type`, `userAssignedIdentities` (not `principalId`)
- **SystemAssigned properties**: `type`, `principalId` (has principal for RBAC)
- **Prevention**: Check ARM template docs for identity type before defining outputs

### Parameter File Validation
- **Rule**: Parameter files MUST contain actual resource names/values, NOT placeholders
- **Audit Finding**: Subscription ID placeholder prevented cross-RG resource references
- **Check**: `az bicep build-params --file {env}.bicepparam --verbose` before deployment
- **Discovery**: `az resource list -g {shared-rg} --query "[].name" -o tsv` to get exact names

### Quota Checks Before App Service Plans
- **Rule**: For Function Apps, check quota BEFORE choosing plan tier
- **Audit Finding**: Y1 Consumption (zero "Dynamic VMs" quota) and EP1 ElasticPremium (zero VM quota) blocked
- **Solution**: Use **Flex Consumption** (quota-free) for dev/proof-of-concept
- **Note**: Flex requires `functionAppConfig` object on Function App creation (see "Common Errors" section)

## 5. Key Project Rules & Patterns

### Security: No Credentials in Tracked Files
**NEVER add actual or example credentials/secrets to any file that is NOT in `.gitignore`.** This includes:
- ❌ API keys, connection strings, UUIDs
- ❌ Example credentials (even as placeholders like `12345678-abcd-...`)
- ❌ Subscription IDs, Client IDs, Tenant IDs, Object IDs
- ❌ Token examples or reference values that look like real credentials

**What to do instead:**
1. Reference `./scripts/setup-oidc.sh` output for credential documentation
2. Use generic placeholders like `{YOUR_SUBSCRIPTION_ID}` or `your-app-id`
3. Direct users to retrieve values from Azure CLI/GitHub Actions output
4. Keep `.gitignore` updated to exclude files with real secrets

**Files that should NEVER contain credentials:**
- `docs/**/*.md` (all documentation)
- `infra/**/*.bicep` and `infra/**/*.bicepparam`
- `.github/workflows/**`
- `scripts/**` (unless the script intentionally outputs secrets to terminal, not files)


### Naming Conventions
- Pattern: `{resourceType}-{workloadName}-{environment}` (e.g., `func-authpilot-dev`, `kv-authpilot-uat`)
- Storage accounts: `st{workloadNoHyphens}{env}` (max 24 chars, no hyphens)

### Module Design
- **Scope**: Resource Group (never subscription scope in modules)
- **Parameters**: Accept `location`, `tags`, resource-specific params
- **Outputs**: IDs, endpoints, principal IDs (for RBAC chains)
- **Dependencies**: Standalone, no external dependencies

### Parameter Flow
- **main.bicep**: Defines parameters + enforcement logic (allowed values, constraints)
- **environments/*.bicepparam**: Environment-specific values only
- **Rule**: No hardcoded values in modules; everything parameterized
- **Tags**: Merge at workload level: `union(tags, {environment, workload, managedBy})`

### RBAC & Security
- **Identity**: All services use User-Assigned Managed Identity
- **Key Vault access**: Grant permissions via `principalId` output
- **Private endpoints**: Enable only in uat/prod (controlled by parameter)

### Bicep Linting (bicepconfig.json)
- **Errors** (must fix): Secure parameters, admin usernames, secrets in commands
- **Warnings** (should fix): Unused params, hardcoded locations, deprecated APIs

## 6. Common Tasks

### Adding a New Module
1. Create: `infra/modules/{category}/new-resource.bicep`
2. Add `@description()` decorators on all parameters
3. Define outputs block with resource IDs/endpoints
4. In workload's main.bicep: Add module deployment with unique symbolic name
5. Update workload's `environments/*.bicepparam` files with new parameters
6. Validate: `az bicep build --file infra/workloads/{workload}/main.bicep --verbose`

### Adding a New Workload
1. Create: `infra/workloads/{workload-name}/main.bicep` (subscription scope)
2. Create: `infra/workloads/{workload-name}/environments/{dev,uat,prod}.bicepparam`
3. Reference modules: `../../modules/{category}/{module}.bicep`
4. Create workflow: `.github/workflows/deploy-{workload-name}.yml`
5. Validate: `az bicep build --file infra/workloads/{workload-name}/main.bicep`

### Debugging Failed Deployments
1. Check build output: `az bicep build --file {changed_bicep_file} --verbose`
2. Check parameters: Confirm all values in `*.bicepparam` are actual (not placeholders)
3. Check RBAC: Ensure managed identity has permissions
4. Check outputs: Verify all referenced outputs exist on their resources
5. **DO NOT delete RG** - Fix template and redeploy (idempotent)

## 7. Common Errors & Fixes

### Error: Storage Account Name Too Long
**Message**: `"value can have length as large as 106... max length 63"`
**Fix**: Use `'st${take(uniqueString(subscription().subscriptionId), 21)}'` (always 23 chars)
**Prevention**: Test with `az bicep build --verbose`

### Error: Read-Only Properties in Child Resources
**Message**: `"sku/tier property is read-only" in blobServices, fileServices`
**Fix**: Remove `sku`/`tier` from child resources; parent storageAccount inherits
**Prevention**: Check ARM template docs; child services cannot override parent SKU

### Error: SubscriptionIsOverQuotaForSku
**Message**: `"Current Limit (ElasticPremium VMs): 0"`
**Fix #1 (Quick)**: Use **Flex Consumption** plan (quota-free)
- Change: `appServicePlanSku = 'EP1'` → `appServicePlanSku = 'Flex'`
- Note: Flex requires `functionAppConfig` object (see below)
**Fix #2 (Permanent)**: Request quota in Azure Portal → Subscriptions → Usage + quotas
**Prevention**: Run `what-if` analysis before deployment (`az deployment sub what-if ... | grep -i quota`)

### Error: API Version Not Available in Region
**Message**: `"No registered resource provider found for location 'westus' and API version '2024-01-01-preview'"`
**Fix**: Use stable GA versions: `@2023-08-01`, `@2023-04-01`
**Prevention**: Never use `-preview` versions; check error message for supported list

### Error: Parameter Not Found / Module Chain Broken
**Message**: `"The template output 'principalId' doesn't exist"` or undefined parameter
**Fix**: Verify module call site passes ALL parameters module expects
**Prevention**: Before deploy, check: Does main.bicep pass `sku` to functionAppModule? Does output match identity type?

### Error: Flex Plan Missing Runtime Configuration
**Message**: `"properties.functionAppConfig is invalid... FunctionAppConfig is required on create"`
**Fix**: Add functionAppConfig object to Function App properties when using Flex:
```bicep
functionAppConfig: {
  deployment: {
    storage: { type: 'blobContainer', value: 'https://...' }
  }
  scaleAndConcurrency: { maximumInstanceCount: 100, instanceMemoryMB: 2048 }
  runtime: { name: 'dotnet-isolated', version: '8.0' }
}
```
**Prevention**: Only use with Flex plan; other plans ignore it

### Error: Parameter File Contains Placeholders
**Message**: `"parameter not found"` or cross-RG resource not found
**Fix**: Parameter files must contain ACTUAL values, not `{YOUR_SUBSCRIPTION_ID}`
**Discovery**: `az resource list -g {shared-rg} --query "[].name" -o tsv`
**Prevention**: Validate: `az bicep build-params --file {env}.bicepparam --verbose`

### Error: Deployment Timeout (False Negative)
**Message**: `"Long-running operation wait cancelled"` (exit 130)
**Fix**: IGNORE. Deployment continues in background. Wait 60 sec, verify: `az resource list -g rg-{workload} -o table`
**Prevention**: Azure CLI messaging issue, not code failure; always verify resources after timeout

### Error: Secrets in Environment Block
**Message**: `"Unrecognized named-value: 'secrets'" on environment.url`
**Fix**: Remove `secrets.*` from `environment` block; use only in `with:`, `env:`, `run:`
**Prevention**: `environment` block is metadata-only; never use secrets context there

## 8. RG Idempotency Rule (Critical)

**If deployment fails on one resource**:
- ❌ **DO NOT** delete the entire Resource Group
- ✅ **DO** keep the RG and fix the template
- ✅ Redeploy to same RG: `az deployment sub create ... (same params)`
- ✅ Resources that succeeded are skipped; failed ones retry with fix

**Why**: RG deletion takes 10+ minutes and loses all context. Template fixes take 2-5 min to redeploy.

**When to delete RG**:
- Only if RG location must change (immutable, requires new RG)
- Or fundamental template design flaw requires rebuild

**Pattern**:
1. Read error: `az deployment sub show -n {deployment-name} --query "properties.error"`
2. Fix Bicep/parameters
3. Redeploy immediately to same RG
4. Verify: `az resource list -g rg-{workload}-{env} -o table`

## 9. Azure CLI Best Practices

### Always Use Verbose Output
- **All `az deployment` commands**: Add `--verbose`
- **All `az bicep` commands**: Use `--stdout` for output capture
- **All background deployments**: Use `2>&1` to capture stderr
- **Never use `> /dev/null`** unless specifically testing build success

**Why**: Azure CLI sometimes swallows output ("The content for this response was already consumed"  ). Verbose mode ensures error messages are visible.

**Correct**:
```bash
az deployment sub create --name {name} --location {region} --template-file {bicep} --parameters {params} --verbose 2>&1 | tee deployment.log
```

**Wrong**:
```bash
az deployment sub create ... > /dev/null  # Silent failures!
```

## 10. Security & Governance

### No Credentials in Tracked Files
- ❌ API keys, connection strings, UUIDs in `.bicep` / `.bicepparam` files
- ❌ Example credentials like `12345678-abcd-...`
- ❌ Subscription IDs, Client IDs, Tenant IDs in documentation
- ✅ Use `{YOUR_SUBSCRIPTION_ID}` placeholder in docs
- ✅ Direct users to Azure CLI output to get actual values
- ✅ Keep `.gitignore` up to date

### GitHub Actions Secrets
- Use GitHub environment secrets for Azure credentials
- Reference in step-level `with:`, `env:`, `run:` blocks ONLY
- Never in `environment.url` or `environment` metadata block