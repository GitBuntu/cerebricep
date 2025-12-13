# Copilot Instructions for `cerebricep`

## Repository Overview

**cerebricep** is an Infrastructure-as-Code (IaC) project for deploying AI workloads to Azure using **Bicep** templates and **GitHub Actions** for CI/CD automation. The project implements a modular, environment-aware infrastructure that supports dev, UAT, and production deployments with security best practices including OIDC authentication and managed identities.

### Key Facts
- **Language**: Bicep (Azure ARM template DSL)
- **Tools**: Azure CLI, GitHub Actions
- **Target**: Azure subscription-level deployments
- **Environments**: dev, uat, prod (cost-optimized for each tier)
- **Size**: ~2.5KB of Bicep code across 10 modules + main orchestration

## Project Architecture

### Major Components
- **infra/main.bicep** - Main orchestration template (subscription scope, ~200 lines)
- **infra/modules/** - Modular Bicep templates organized by domain:
  - `ai/` - Document Intelligence
  - `compute/` - Function App + App Service Plan
  - `config/` - Key Vault, App Configuration
  - `data/` - Cosmos DB, Storage Account
  - `identity/` - User-Assigned Managed Identity
  - `monitoring/` - Log Analytics, Application Insights
- **infra/environments/** - Parameter files for dev/uat/prod:
  - `dev.bicepparam` - Cost-optimized (Consumption Y1, F0 SKUs, 400 RU/s)
  - `uat.bicepparam` - Balanced (Premium EP1, S0 SKUs, 1000 RU/s, private endpoints enabled)
  - `prod.bicepparam` - High-availability (Premium EP2, S0 SKUs, 4000 RU/s, zone redundancy enabled)
- **bicepconfig.json** - Bicep linting rules (strict security/naming conventions)

### Deployment Flow
All resources use **User-Assigned Managed Identity** for authentication (no stored secrets). Deployment order is enforced:
1. Resource Group
2. Monitoring (Log Analytics + App Insights) - other resources depend on this
3. Identity (Managed Identity)
4. Key Vault (RBAC with managed identity principal)
5. Storage, Cosmos DB, App Configuration (with managed identity RBAC)
6. Document Intelligence
7. Function App (wired to all above services)

## Build & Validation Commands

### Prerequisites
- **Azure CLI** (v2.60+) with Bicep support installed: `az bicep upgrade`
- **az login** credentials configured
- **GitHub environment variables** set in Actions: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_REGION`

### Bicep Validation (Always Run Before Committing)
```bash
# Lint and validate syntax for main template
az bicep build --file infra/main.bicep --stdout > /dev/null

# Validate all modules (check each module builds without external dependencies)
az bicep build --file infra/modules/compute/function-app.bicep --stdout > /dev/null
az bicep build --file infra/modules/config/key-vault.bicep --stdout > /dev/null
az bicep build --file infra/modules/data/cosmos-db.bicep --stdout > /dev/null
az bicep build --file infra/modules/data/storage-account.bicep --stdout > /dev/null
az bicep build --file infra/modules/config/app-configuration.bicep --stdout > /dev/null
az bicep build --file infra/modules/ai/document-intelligence.bicep --stdout > /dev/null
az bicep build --file infra/modules/identity/user-assigned-identity.bicep --stdout > /dev/null
az bicep build --file infra/modules/monitoring/log-analytics.bicep --stdout > /dev/null
```
**Success Indicator**: Outputs valid ARM template JSON with no warnings/errors (warnings about Bicep versions can be ignored).

### Parameter File Validation
```bash
# Each bicepparam file is validated when referenced by GitHub Actions, but you can test locally
az bicep build-params --file infra/environments/dev.bicepparam --outfile dev.parameters.json
```

## Key Project Rules & Patterns

### Naming Conventions (Bicep)
- All resource names follow a strict pattern in `main.bicep`: `{resourceType}-{workloadName}-{environment}`
- Storage account names: `st{workloadNameNoHyphens}{environment}` (no hyphens, max 24 chars)
- Example: `func-cerebricep-dev`, `kv-cerebricep-prod`, `cosmos-cerebricep-uat`

### Module Structure
Every module:
- **Accepts**: `location`, `tags`, resource-specific parameters
- **Outputs**: resource IDs, connection strings, endpoints, principal IDs (for RBAC chains)
- **Uses**: Resource Group scope (not subscription scope)
- **Depends on**: Nothing external (standalone, composable)

### Parameter Flow
- **main.bicep** defines top-level parameters and enforcement logic (allowed values, constraints)
- **environment/*.bicepparam** files provide environment-specific values
- **No hardcoded values** in module files - everything parameterized
- **Tags** are merged at main template level: `union(tags, {environment, workload, managedBy})`

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
3. Add module deployment to `infra/main.bicep` with unique `name: 'resource-${uniqueString(deployment().name)}'`
4. Add outputs to `main.bicep` outputs block
5. Run `az bicep build --file infra/main.bicep --stdout > /dev/null` to validate
6. Update all three `*.bicepparam` files with new parameters

### Updating Parameters
- **Never modify `main.bicep` parameter defaults** - change them in `infra/environments/{env}.bicepparam` instead
- Test with: `az bicep build-params --file infra/environments/dev.bicepparam --outfile dev.parameters.json`
- Ensure parameter names match exactly between `main.bicep` and `*.bicepparam`

### Debugging Deployments
When a GitHub Actions deployment fails:
1. Check the "Validate" step output for Bicep errors (run `az bicep build --file infra/main.bicep` locally to reproduce)
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
- **Environment staging**: dev auto-deploys from main branch; uat/prod require manual workflow dispatch
- **No environment-specific bicep files** - use bicepparam for all variations
- **Managed identity must be deployed first** - all other modules reference its outputs

---

**Trust these instructions.** Search the codebase only if you encounter an error or if information here is incomplete. Check `docs/architecture.md` and `docs/deployment-guide.md` for deeper architectural details.
