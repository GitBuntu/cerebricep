# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

**Language/Version**: Bicep (Azure ARM template DSL) + PowerShell 7.x  
**Primary Dependencies**: Azure CLI v2.60+, Bicep CLI, GitHub Actions  
**Storage**: Azure SQL Database, Azure Storage Account, Azure Cosmos DB (future)  
**Testing**: Bicep build validation, Azure what-if analysis, schema validation  
**Target Platform**: Azure (cross-region capable)  
**Project Type**: Infrastructure-as-Code (IaC) workload deployment  
**Performance Goals**: Deployment < 10 minutes, query response < 1 second  
**Constraints**: Cross-RG resource referencing (shared RG + app RG), managed identity authentication, no credential storage  
**Scale/Scope**: MVP 100 calls/day, ~$122/month, enterprise architecture pattern (shared + isolated resources)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Constitution Principles vs. Feature Requirements

| Principle | Requirement | Status | Justification |
|-----------|-------------|--------|---------------|
| **I. Workload-Centric Independence** | New workload `healthcare-call-agent` must be isolated from `authpilot` and all other workloads | ✅ PASS | Feature spec explicitly requires separate resource group + independent deployment pipeline. Cross-RG referencing does NOT violate isolation (reads from shared RG, creates in app RG). |
| **II. Module Reusability & Composability** | All new infrastructure components must be modules in `infra/modules/` with parameterized inputs | ⚠️ CONDITIONAL PASS | Existing modules (app-service-plan, function-app, key-vault, storage-account, cosmos-db, user-assigned-identity) are reusable. If new capabilities needed (e.g., Azure SQL Database module), must be added following module guidelines. Shared resources (ACS, AI Services) are READ-ONLY via CLI queries, not modules. |
| **III. Infrastructure-as-Code Rigor** | 100% Bicep templates, no imperative scripts; all resources version-controlled and repeatable | ✅ PASS | Feature requires IaC deployment via GitHub Actions. Cross-RG queries via Bicep `resourceId()` function and `listKeys()` to reference existing resources. No imperative scripts beyond standard Az CLI syntax in templates. |
| **IV. Security: No Credentials in Version Control** | No connection strings, keys, subscription IDs, or reference values committed to tracked files | ✅ PASS | Feature explicitly requires managed identity authentication. All sensitive values (ACS connection string, AI Services keys) injected at deployment time via GitHub Actions secrets → Key Vault → managed identity. Zero credentials in Bicep or bicepparam files. |
| **V. Consistent Naming & Parameterization** | Resource naming follows `{resourceType}-{workloadName}-{environment}` pattern; environment values in `*.bicepparam` | ✅ PASS | Feature spec proposes `func-healthcare-call-agent-{env}`, `sql-healthcare-call-agent-{env}`, etc. All environment variables parameterized in `healthcare-call-agent/*.bicepparam` files. |

**Gate Result**: ✅ **PASS** — Feature is architecturally sound and aligns with all 5 core principles. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/001-call-agent-deploy/
├── plan.md                 # This file (/speckit.plan command output)
├── research.md             # Phase 0 output (/speckit.plan command)
├── data-model.md           # Phase 1 output (/speckit.plan command)
├── quickstart.md           # Phase 1 output (/speckit.plan command)
├── contracts/              # Phase 1 output (/speckit.plan command)
│   ├── deployment-schema.json
│   └── resource-outputs.json
├── spec.md                 # Original feature specification
├── checklists/
│   └── requirements.md
└── tasks.md                # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Infrastructure-as-Code (IaC) - Bicep Templates

```text
infra/
├── modules/
│   ├── ai/
│   │   └── document-intelligence.bicep         # (existing, reusable)
│   ├── compute/
│   │   ├── app-service-plan.bicep              # (reusable)
│   │   └── function-app.bicep                  # (reusable)
│   ├── config/
│   │   ├── key-vault.bicep                     # (reusable)
│   │   └── app-configuration.bicep             # (reusable)
│   ├── data/
│   │   ├── cosmos-db.bicep                     # (reusable)
│   │   ├── documentdb.bicep                    # (reusable)
│   │   ├── storage-account.bicep               # (reusable)
│   │   └── [NEW] sql-database.bicep            # Phase 1: Create if not exists
│   ├── identity/
│   │   └── user-assigned-identity.bicep        # (reusable)
│   ├── messaging/
│   │   └── event-grid.bicep                    # (existing, reusable if needed)
│   └── monitoring/
│       ├── action-groups.bicep                 # (reusable)
│       ├── application-insights.bicep          # (reusable)
│       └── log-analytics.bicep                 # (reusable)
└── workloads/
    ├── authpilot/                              # (existing workload, unchanged)
    │   ├── main.bicep
    │   └── environments/
    │       ├── dev.bicepparam
    │       ├── uat.bicepparam
    │       └── prod.bicepparam
    └── [NEW] healthcare-call-agent/
        ├── main.bicep                          # Subscription-scope orchestration
        ├── DEPLOYMENT-NOTES.md                 # Deployment guide
        └── environments/
            ├── dev.bicepparam
            ├── uat.bicepparam
            └── prod.bicepparam
```

**Structure Decision**: 
- **Workload Pattern**: Healthcare Call Agent follows the workload-centric architecture established by authpilot. It is a completely independent workload with its own `main.bicep` at subscription scope and environment-specific parameter files.
- **Module Reuse**: The workload composes existing modules (function-app, storage-account, key-vault, user-assigned-identity, log-analytics) and may require a new `sql-database.bicep` module if not currently available.
- **Cross-RG Referencing**: The workload's `main.bicep` queries shared resources (ACS, AI Services) from `rg-vm-prod-canadacentral-001` using Azure CLI commands embedded in the template via the `resourceId()` function and variable interpolation. Connection strings and endpoints are retrieved at deployment time and injected into Function App settings.
- **No New Directories**: All code remains within the existing `infra/` structure; no new top-level directories are introduced.

## Complexity Tracking

No constitutional violations identified. Feature is ready for Phase 0 research.

---

## Implementation Phases

### Phase 0: Research & Clarifications (In Progress)
1. **Cross-RG Resource Referencing**: Document the pattern for querying resources from shared RG in Bicep
2. **Azure SQL Database Module**: Determine if existing `sql-database.bicep` module exists; if not, design new module
3. **GitHub Actions RBAC Configuration**: Define minimum required permissions for GitHub service principal to read from shared RG and deploy to app RG
4. **Cost Analysis**: Validate MVP cost projections (~$122/month for new resources)
5. **Security Hardening Roadmap**: Document Phase 2 upgrades (Key Vault, VNet, private endpoints, HTTPS enforcement)

### Phase 1: Design & Contracts (Planned)
1. Create `data-model.md` defining resource dependencies and relationships
2. Define `healthcare-call-agent/main.bicep` orchestration template (subscription scope)
3. Create parameter files: `dev.bicepparam`, `uat.bicepparam`, `prod.bicepparam`
4. Generate API contracts for cross-RG resource queries
5. Create quickstart.md deployment guide
6. Update agent context with Bicep best practices and cross-RG patterns

### Phase 2: Implementation (Deferred to /speckit.tasks)
1. Implement healthcare-call-agent workload templates
2. Create SQL Database module if needed
3. Implement GitHub Actions deployment workflow
4. Deploy to dev environment and validate
5. Document deployment process in DEPLOYMENT-NOTES.md
