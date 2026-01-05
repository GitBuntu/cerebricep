# Copilot Instructions for `cerebricep`

## Repository Overview

**cerebricep** is an Infrastructure-as-Code (IaC) project for deploying workloads to Azure using **Bicep** templates and **GitHub Actions** for CI/CD automation. The project implements a **workload-centric architecture** where each workload is completely self-contained with its own main template, parameters, and deployment pipeline.

### Key Facts
- **Language**: Bicep (Azure ARM template DSL)
- **Tools**: Azure CLI, GitHub Actions
- **Target**: Azure subscription-level deployments (each workload creates its own resource group)
- **Architecture**: Workload-centric (independent deployments, zero cross-workload dependencies)

## Project Architecture

### Workload-Centric Structure
```
infra/
├── modules/              # Shared reusable building blocks
│   ├── ai/
│   ├── compute/
│   ├── config/
│   ├── data/
│   ├── identity/
│   └── monitoring/
└── workloads/
    └── authpilot/        # Self-contained workload
        ├── main.bicep    # Subscription-scope orchestration
        └── environments/
            ├── dev.bicepparam
            ├── uat.bicepparam
            └── prod.bicepparam
```

### Core Principles
1. **Each workload is independent** - Has its own `main.bicep` and parameter files
2. **No shared main template** - Workloads compose modules they need
3. **Single source of truth** - Workload's `main.bicep` + `environments/*.bicepparam` contain everything
4. **Zero cross-workload impact** - Changes to one workload don't affect others
5. **No scripts** - Everything defined in Bicep templates (repeatable, version-controlled)

### Shared Modules (infra/modules/)
Reusable building blocks organized by domain:
- `ai/` - Document Intelligence
- `compute/` - Function App + App Service Plan  
- `config/` - Key Vault, App Configuration
- `data/` - Cosmos DB, DocumentDB (MongoDB), Storage Account
- `identity/` - User-Assigned Managed Identity
- `monitoring/` - Log Analytics, Application Insights

**Module characteristics:**
- Resource Group scope (not subscription scope)
- Standalone (no external dependencies)
- Accept: `location`, `tags`, resource-specific parameters
- Output: resource IDs, endpoints, principal IDs (for RBAC chains)

### Current Workloads

#### AuthPilot
- **Location**: `infra/workloads/authpilot/`
- **Purpose**: Fax processing with DocumentDB (MongoDB)
- **Deployed Resources**: Resource Group + DocumentDB
- **Modules Used**: `modules/data/documentdb.bicep`
- **Workflow**: `.github/workflows/deploy-authpilot.yml`

## Build & Validation Commands

### Prerequisites
- **Azure CLI** (v2.60+) with Bicep support installed: `az bicep upgrade`
- **az login** credentials configured
- **GitHub environment variables** set in Actions: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

### Validating a Workload (Always Run Before Committing)
```bash
# Validate authpilot workload
az bicep build --file infra/workloads/authpilot/main.bicep --stdout > /dev/null
az bicep build-params --file infra/workloads/authpilot/environments/dev.bicepparam --outfile /dev/null

# Validate individual shared modules (optional)
az bicep build --file infra/modules/data/documentdb.bicep --stdout > /dev/null
```

### Deploying a Workload
```bash
# Deploy authpilot to dev environment
az deployment sub create \
  --location eastus \
  --template-file infra/workloads/authpilot/main.bicep \
  --parameters infra/workloads/authpilot/environments/dev.bicepparam
```

**Success Indicator**: Outputs valid ARM template JSON with no warnings/errors (warnings about Bicep versions can be ignored).

## Key Project Rules & Patterns

### 🔒 CRITICAL SECURITY RULE: No Credentials in Tracked Files
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

### Naming Conventions (Bicep)
- All resource names follow pattern: `{resourceType}-{workloadName}-{environment}`
- Storage account names: `st{workloadNameNoHyphens}{environment}` (no hyphens, max 24 chars)
- Example: `func-authpilot-dev`, `mongodb-authpilot-prod`, `kv-authpilot-uat`

### Module Structure
Every module:
- **Accepts**: `location`, `tags`, resource-specific parameters
- **Outputs**: resource IDs, connection strings, endpoints, principal IDs (for RBAC chains)
- **Uses**: Resource Group scope (not subscription scope)
- **Depends on**: Nothing external (standalone, composable)

### Parameter Flow
- **Workload main.bicep** defines parameters and enforcement logic (allowed values, constraints)
- **environments/*.bicepparam** files provide environment-specific values
- **No hardcoded values** in module files - everything parameterized
- **Tags** are merged at workload template level: `union(tags, {environment, workload, managedBy})`

### RBAC & Security
- All services authenticated via **User-Assigned Managed Identity**
- Key Vault grants permissions to identity via `principalId` (e.g., `identity.outputs.principalId`)
- Function App environment variables reference Key Vault URI + managed identity client ID
- Private endpoints enabled only in uat/prod (controlled via `enablePrivateEndpoints` param)

### Bicep Linting Rules (bicepconfig.json)
- **Errors** (must fix): `secure-parameter-default`, `use-secure-value-for-secure-inputs`, `adminusername-should-not-be-literal`, `protect-commandtoexecute-secrets`
- **Warnings** (should fix): `no-unused-params`, `no-unused-vars`, `simplify-interpolation`, `no-hardcoded-location`, `no-hardcoded-env-urls`

## Common Tasks for Agents

### Adding a New Module
1. Create file: `infra/modules/{category}/new-resource.bicep`
2. Follow this structure:
   - Comments with `// ==== ... ====` section dividers
   - `@description()` decorator on every parameter
   - Output block with all relevant resource IDs/endpoints
3. Add module deployment to workload's `main.bicep` with unique `name: 'modulename-${uniqueString(deployment().name)}'`
4. Add outputs to workload's `main.bicep` outputs block
5. Run `az bicep build --file infra/workloads/{workload}/main.bicep --stdout > /dev/null` to validate
6. Update workload's `environments/*.bicepparam` files with new parameters

### Adding a New Workload
1. Create directory: `infra/workloads/{workload-name}/`
2. Create `main.bicep` (subscription scope, creates resource group, composes needed modules)
3. Create `environments/dev.bicepparam` (and uat/prod as needed)
4. Reference modules using relative path: `../../modules/{category}/{module}.bicep`
5. Create GitHub workflow: `.github/workflows/deploy-{workload-name}.yml`
6. Validate: `az bicep build --file infra/workloads/{workload-name}/main.bicep`

### Updating Parameters
- **Never modify workload `main.bicep` parameter defaults** - change them in `environments/{env}.bicepparam` instead
- Test with: `az bicep build-params --file infra/workloads/{workload}/environments/dev.bicepparam --outfile /dev/null`
- Ensure parameter names match exactly between `main.bicep` and `*.bicepparam`

### Debugging Deployments
When a GitHub Actions deployment fails:
1. Check the "Validate" step output for Bicep errors (run `az bicep build --file infra/workloads/{workload}/main.bicep` locally to reproduce)
2. Look for RBAC issues (managed identity may not have permission to access Key Vault) - add `principalId` grant in Key Vault module
3. Verify all module outputs referenced in dependent modules exist
4. Check environment variables in GitHub environment settings match parameter file expectations

## Testing & Validation Pipeline

All pull requests automatically run:
- **Bicep Build & Lint** - Checks syntax and bicepconfig.json rules
- **What-If Analysis** - Previews ARM template changes (when credentials available)
- **Security Scan** - Checkov security validation (if configured)

**To replicate locally** for any file changed:
```bash
az bicep build --file {changed_bicep_file}
```

## Important Constraints & Notes

- **Always deploy to resource group scope** in modules, not subscription scope
- **Module dependencies**: Function App module depends on all 7 other modules (ensure outputs exist)
- **Recommended environment staging**: Configure dev to auto-deploy from main branch; require manual workflow dispatch for uat/prod
- **No environment-specific bicep files** - use bicepparam for all variations
- **Managed identity must be deployed first** - all other modules reference its outputs

---

**Trust these instructions.** Search the codebase only if you encounter an error or if information here is incomplete. Check `docs/architecture.md` and `docs/deployment-guide.md` for deeper architectural details.