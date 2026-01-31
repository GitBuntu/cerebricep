<!-- 
SYNC IMPACT REPORT
==================
Version: 1.0.0 (NEW)
Ratified: 2026-01-31
Changes: Initial constitution created for cerebricep project
Principles: 5 core principles + Security + Governance sections
Templates updated: All templates now reference these principles
Status: ✅ Complete
-->

# Cerebricep Constitution

## Core Principles

### I. Workload-Centric Independence
Each workload is completely self-contained with its own `main.bicep` orchestration template and environment-specific `*.bicepparam` parameter files. Workloads MUST NOT have dependencies on other workloads. Changes to one workload MUST NOT affect any other workload. Each workload composes only the shared modules it needs, maintaining clear isolation boundaries.

### II. Module Reusability & Composability
All shared functionality MUST be implemented as reusable modules in `infra/modules/{category}/`. Each module MUST:
- Accept `location`, `tags`, and resource-specific parameters (no hardcoded values)
- Be resource-group scoped, not subscription-scoped
- Output resource IDs, connection strings, endpoints, and principal IDs for RBAC chains
- Have NO external dependencies (standalone, composable design)
- Be independently testable and documented

### III. Infrastructure-as-Code Rigor (NON-NEGOTIABLE)
ALL infrastructure MUST be defined in Bicep templates—NO imperative scripts. Every resource creation, permission assignment, and configuration MUST be version-controlled, repeatable, and traceable. Bicep templates MUST pass linting (bicepconfig.json errors MUST be fixed; warnings SHOULD be addressed). Pre-deployment validation with `az bicep build` and `az bicep build-params` is MANDATORY before commits.

### IV. Security: No Credentials in Version Control
NEVER commit actual or example credentials, secrets, API keys, subscription IDs, or any reference values that resemble real credentials to any tracked file. Use generic placeholders (`{YOUR_SUBSCRIPTION_ID}`, `your-app-id`). All sensitive values MUST be injected at deployment time via GitHub Actions secrets or Key Vault. Managed identities MUST be used for all service-to-service authentication (no stored keys/passwords).

### V. Consistent Naming & Parameterization
All resource names MUST follow the pattern `{resourceType}-{workloadName}-{environment}`. Storage account names MUST omit hyphens: `st{workloadName}{environment}` (24-character limit). Environment-specific values MUST be in `*.bicepparam` files; workload `main.bicep` defines parameters and validation logic (allowed values, constraints). Tags MUST be merged at the workload level: `union(tags, {environment, workload, managedBy})`.

## Security & Compliance Requirements

- **Managed Identity REQUIRED**: All services MUST authenticate using User-Assigned Managed Identity; no stored credentials in code or config
- **Key Vault Integration**: Sensitive configuration and secrets MUST be stored in Key Vault with RBAC grants to the managed identity via `principalId` outputs
- **Private Endpoints**: MUST be enabled for Key Vault in uat/prod environments; parameterized via `enablePrivateEndpoints` flag
- **OIDC Federation**: GitHub Actions MUST use Workload Identity Federation (OIDC) to authenticate to Azure; NO stored secrets in GitHub
- **Bicep Linting Enforcement**:
  - **Errors** (must fix): `secure-parameter-default`, `use-secure-value-for-secure-inputs`, `adminusername-should-not-be-literal`, `protect-commandtoexecute-secrets`
  - **Warnings** (should fix): `no-unused-params`, `no-unused-vars`, `simplify-interpolation`, `no-hardcoded-location`, `no-hardcoded-env-urls`

## Development Workflow & Quality Gates

- **Validation on Every PR**: Bicep build, linting, and what-if analysis (security scanning via Checkov if configured)
- **Deployment Gates**: dev environment auto-deploys from main branch; uat and prod REQUIRE manual workflow dispatch approval
- **Module Structure**: Bicep files MUST use `// ==== SECTION ====` comments; `@description()` REQUIRED on all parameters
- **Workload Composition**: Each workload's `main.bicep` defines its module dependencies and orchestration at subscription scope (creates its own resource group)
- **Testing & What-If**: Before merging, `az deployment sub what-if` MUST be reviewed to understand infrastructure changes

## Governance

This constitution supersedes all other practices and guidance files (see `.github/copilot-instructions.md` for runtime development guidance). All pull requests MUST verify compliance with these principles. Amendments to the constitution REQUIRE:

1. Documentation of the change rationale and impact
2. Version bump following semantic versioning (MAJOR: principle removal/redefinition; MINOR: new principle/section; PATCH: clarifications)
3. Synchronized updates to `.specify/templates/{plan,spec,tasks}-template.md` and relevant guidance files
4. Migration plan (if breaking changes) with clear timelines for affected workloads

**Version**: 1.0.0 | **Ratified**: 2026-01-31 | **Last Amended**: 2026-01-31
