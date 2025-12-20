# Lessons Learned: AuthPilot Infrastructure Deployment

## Deployment Challenges & Solutions

### Quota Issues & SKU Selection
**Problem**: Consumption plan (`Y1`) hit regional subscription quota limits (0 available instances in East US for free/trial subscriptions).
- **Initial attempt**: ElasticPremium (EP1) → Quota exhaustion
- **Second attempt**: Consumption (Y1) → Regional quota: 0 instances available
- **Solution**: **Flex Consumption (`'Flex'` SKU)** - No regional quota constraints, scales to 1000 instances, ideal for free/trial subscriptions

**Key Learning**: Free/trial subscriptions have different default regional quotas than Enterprise Agreement subscriptions. Always check actual quota availability before assuming a SKU will work.

---

### Bicep SKU Mapping for Flex
**Problem**: Passing `sku = 'Flex'` to ARM template failed with "invalid SKU.Name"
- **Root cause**: ARM template requires `sku.Name = 'FC1'` and `sku.Tier = 'FlexConsumption'`
- **Solution**: Map Bicep parameter `sku = 'Flex'` to ARM template values:
  ```bicep
  var skuName = isFlex ? 'FC1' : sku
  var skuTier = isFlex ? 'FlexConsumption' : 'ElasticPremium'
  ```

**Key Learning**: Bicep's allowed SKU values may differ from ARM template's actual `sku.Name` values. Always map intelligible names to exact ARM requirements.

---

### Flex Consumption Site Configuration Requirements
**Problem**: Multiple deployment failures due to invalid site configuration for Flex:

1. **`linuxFxVersion` error**: "LinuxFxVersion is invalid for Flex Consumption sites"
   - **Root cause**: Flex specifies runtime in `functionAppConfig.runtime`, not `siteConfig.linuxFxVersion`
   - **Solution**: Conditionally exclude `linuxFxVersion` from `siteConfig` for Flex plans

2. **`functionAppConfig` requirement error**: "FunctionAppConfig is required on create for FlexConsumption sites"
   - **Root cause**: Flex requires explicit deployment storage and runtime configuration
   - **Solution**: Add `functionAppConfig` block with deployment storage, scaleAndConcurrency, and runtime properties

3. **`FUNCTIONS_WORKER_RUNTIME` app setting error**: "FUNCTIONS_WORKER_RUNTIME is invalid for Flex Consumption sites"
   - **Root cause**: Flex specifies runtime in `functionAppConfig.runtime`, not app settings
   - **Solution**: Conditionally exclude `FUNCTIONS_WORKER_RUNTIME` from app settings for Flex plans

**Key Learning**: Different SKUs have different configuration requirements. Use completely separate config objects (not conditionals with `null`) to ensure invalid properties are never included in the generated ARM template.

---

### Environment-Aware Naming for Idempotency
**Problem**: Deterministic naming (`-001` suffix) caused conflicts on retry deployments; resource already existed with same name.
- **Solution**: Environment-conditional naming:
  - **Dev**: Unique suffix using `take(uniqueString(deployment().name), 5)` - allows repeated safe redeployment
  - **Prod**: Fixed suffix `-001` - stable, predictable names

**Key Learning**: Infrastructure-as-code requires idempotent deployments. Dev environments benefit from unique naming per deployment; production requires stable, fixed names.

---

## What Finally Worked

✅ **Bicep Template Configuration** (Final Working State):
- Flex Consumption plan (`skuName = 'FC1'`, `skuTier = 'FlexConsumption'`)
- Separate `siteConfigFlex` (without `linuxFxVersion`, without `FUNCTIONS_WORKER_RUNTIME`)
- Separate `appSettingsFlex` (excludes `FUNCTIONS_WORKER_RUNTIME`)
- `functionAppConfig` with deployment storage, scale settings, and runtime
- .NET 9.0 runtime (`dotnet-isolated`)
- Managed identity authentication (no hardcoded storage keys in code)

**Deployment Command**:
```bash
DEPLOYMENT_NAME="authpilot-dev-$(date +%Y%m%d-%H%M%S)"
az deployment sub create \
  --name $DEPLOYMENT_NAME \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters infra/workloads/authpilot/dev.bicepparam
```

---

## Key Architectural Lessons

### Resource Naming Conventions
**Learning**: Implement unique identifiers and environment-specific suffixes in resource names to avoid conflicts and ensure differentiation across deployments.
- **Pattern**: `{resourceType}-{workloadName}-{environment}` (e.g., `func-cerebricep-dev`, `kv-cerebricep-prod`, `cosmos-cerebricep-uat`)
- **Storage accounts**: `st{workloadNameNoHyphens}{environment}` (no hyphens, max 24 chars, e.g., `stcerebricepdev`)
- **Dev environments**: Use `take(uniqueString(deployment().name), 5)` suffix for idempotent redeployments
- **Production**: Use fixed suffixes (e.g., `-001`) for stable, predictable resource names
- **Benefit**: Prevents naming conflicts across multiple deployments, PRs, and environments

**Referenced**: PRs #27, #30, #33

---

### Cost Optimization for Dev Environments
**Learning**: Use free or minimum-cost tiers and avoid enterprise features during development to minimize costs:
- **Function App**: `Y1` Consumption plan (or `Flex` for quota-constrained free subscriptions)
- **Cosmos DB**: 400 RU/s (minimum provisioned throughput)
- **Document Intelligence**: `F0` free tier (1 page/month; upgrade to `S0` for production)
- **Key Vault & Storage**: Standard tier with no redundancy
- **Disable**: Private endpoints, zone redundancy, and advanced monitoring in dev
- **Result**: 70-80% cost reduction vs. production-equivalent setup

**Referenced**: PRs #28, #29, #31

---

### Dynamic SKU Handling
**Learning**: Derive SKU names and configurations conditionally in Bicep modules to support flexible deployments across free/trial/enterprise subscriptions:
- Use `isFlex` variable to conditionally map `'Flex'` → `skuName = 'FC1'` and `skuTier = 'FlexConsumption'`
- Maintain separate configuration objects (`siteConfigFlex` vs. `siteConfigStandard`) rather than using conditional `null` properties
- Different SKUs require different mandatory properties—ensure Bicep models match ARM template requirements exactly
- **Validation**: Always test with `az bicep build-params` before deployment

**Referenced**: PRs #35, #36

---

### OIDC and Permissions Setup
**Learning**: Ensure proper workload identity federation, role assignments, and GitHub Actions permissions for secure, automated deployments:
- **Workload Identity Federation**: Configure federated credentials with `github.com/{owner}/{repo}` subject filter and GitHub token issuer
- **Role Assignments**: Assign `User Access Administrator` or `Owner` role to the service principal at subscription scope (required to grant permissions to other resources via RBAC)
- **GitHub Actions Permissions**: Configure required scopes in workflow:
  - `id-token: write` - Obtain OIDC token from GitHub
  - `contents: read` - Read repository contents
- **Managed Identity RBAC**: Grant permissions using `principalId` outputs; no hardcoded credentials in environment variables
- **Key Vault Access**: Assign `Key Vault Secrets User` and `Key Vault Secrets Officer` roles to the managed identity
- **Deployment Script**: Use `scripts/setup-oidc.sh` to automate federated credential and role assignment setup

**Referenced**: PRs #23, #24, #29

---

### Module Refactoring
**Learning**: Break down complex modules into reusable components and update configurations for better maintainability and scalability:
- **Module Responsibilities**: Each module should handle one resource or tightly-coupled group (e.g., `function-app.bicep` handles App Service Plan + Function App + site config)
- **Reusable Outputs**: Export resource IDs, principal IDs (for RBAC), and endpoints to enable module chaining
- **Configuration Separation**: App settings, site configs, and RBAC should be parameterized, not hardcoded
- **Dependency Management**: Define explicit outputs that downstream modules depend on; enforce deployment order at orchestration level (`main.bicep`)
- **Pattern**: Monitoring → Identity → Config (Key Vault) → Data → Compute, ensuring each layer has required outputs for the next

**Referenced**: PRs #28, #37, #40

---

### Environment-Specific Parameters
**Learning**: Maintain separate parameter files for dev/uat/prod with tailored settings, and validate deployment scopes:
- **File Structure**: `infra/environments/{dev,uat,prod}.bicepparam` - one file per environment
- **Parameter Validation**: Use `az bicep build-params --file {file}.bicepparam` to catch missing/invalid parameters early
- **Scope Enforcement**: Subscription-level deployments for resource groups; resource group scope for all contained resources
- **Settings per Environment**:
  - **Dev**: Minimal resources, free tiers, unique naming, no redundancy
  - **UAT**: Balanced setup, private endpoints enabled, S0 tiers, moderate RU/s (1000)
  - **Prod**: High-availability, zone redundancy, premium SKUs, higher RU/s (4000+)
- **No Hardcoding**: All differences should be expressed via parameter files, never via separate bicep files

**Referenced**: PRs #23, #26, #32

---

### Workflow and Validation Enhancements
**Learning**: Integrate what-if checks, Bicep linting, and CI/CD approvals to catch issues early:
- **Bicep Linting**: Run `az bicep build` in CI pipeline; enforce `bicepconfig.json` rules (security, naming conventions)
- **What-If Analysis**: Run `az deployment sub what-if` to preview ARM template changes before applying
- **Parameter Validation**: Validate all `.bicepparam` files build without errors
- **Approval Gates**: Require manual approval for prod deployments; auto-deploy dev/uat on successful validation
- **Error Handling**: Log full diagnostic output (diagnostic string, ARM template errors) on deployment failures; iterate based on specific error messages
- **Testing**: Validate templates locally before pushing; replicate CI failures with exact commands

**Referenced**: PRs #23, #24

---

### Identity and Access Management
**Learning**: Use user-assigned managed identities and configure role assignments to ensure secure, passwordless access control:
- **Managed Identity Pattern**: Every workload (Function App, etc.) uses a user-assigned managed identity, never system-assigned
- **RBAC Setup**: Assign roles (e.g., Key Vault Secrets User, Storage Blob Data Contributor, Cosmos DB Account Reader) to the managed identity principal
- **Key Vault Integration**: Function App retrieves secrets via managed identity; no connection strings stored in app settings
- **Deployment Identity**: Service principal used only for ARM template deployment; all runtime access via managed identity
- **Principle**: Minimize credentials; use Azure AD identities whenever possible
- **Benefit**: No credential rotation; leverages Azure RBAC audit trail; supports multi-tenant scenarios

**Inferred from**: PR #10 and subsequent identity-related iterations

---

## Recommendations for Future Infrastructure Deployments

1. **Validate quota availability early**: Check actual regional quotas before committing to a SKU
2. **Use Flex Consumption for cost-sensitive/free deployments**: No regional quota constraints; scales to 1000 instances
3. **Separate config objects by SKU**: Avoid conditional properties with `null`—generate completely different configs
4. **Enable environment-aware naming**: Dev = unique per deployment, Prod = stable fixed names
5. **Test with `az bicep build-params` before deployment**: Catches parameter file issues early
6. **Log deployment details**: Use `--query "properties.{provisioningState, timestamp}"` to track deployment progression
