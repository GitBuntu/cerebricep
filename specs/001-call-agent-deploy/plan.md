# Implementation Plan: Healthcare Call Agent MVP - Cross-RG Infrastructure Deployment

**Branch**: `001-call-agent-deploy` | **Date**: February 7, 2026 | **Spec**: [001-call-agent-deploy/spec.md](spec.md)
**Input**: Feature specification from `/specs/001-call-agent-deploy/spec.md`

**Note**: This plan is generated from the feature specification and guides Phase 1-2 implementation activities.

## Summary

Deploy production-ready Healthcare Call Agent MVP using cross-resource-group IaC pattern. Reuse shared Azure Communication Services and AI Services from `rg-vm-prod-canadacentral-001`, while provisioning new application resources (Functions, SQL, Storage) in `rg-healthcare-call-agent-prod`. IaC deployment must query shared resources, inject values into Functions App configuration, and enable secure RBAC-based cross-RG resource referencing.

**Target Load**: 100 calls/day (1.4 concurrent avg, 5 concurrent peak)  
**Cost Target**: ~$122/month total (~$7/month new resources + ~$115/month shared resources)

## Technical Context

**IaC Language**: Bicep (Azure ARM template DSL)  
**API Version**: Azure Key Vault 2026-02-01+ (Phase 2 compliance required by Feb 27, 2027)  
**Storage**: Azure SQL Database (Basic tier, 5 DTU) + Azure Storage Account (Standard V2, LRS)  
**Primary Services**: Azure Functions (Consumption), Azure SQL, Azure Communication Services (shared), Azure AI Services (shared)  
**Testing**: Bicep build validation (`az bicep build`), parameter validation (`az bicep build-params`), post-deployment acceptance tests  
**Target Platform**: Azure Cloud (East US 2 region)  
**Project Type**: Infrastructure-as-Code (IaC) workload deployment  
**Performance Goals**: Infrastructure provisioning < 20 minutes, Functions cold start < 3s, SQL queries < 1s  
**Constraints**: MVP cost < $10/month for new resources, no VNet/Private Endpoints (Phase 2), no Key Vault (Phase 2)  
**Scale/Scope**: Single workload, 4-5 resources, cross-RG referencing pattern

## Constitution Check

**Status**: ✅ **PASS** - This feature complies with cerebricep constitution

**Verified Principles**:
- ✅ **Workload-Centric Independence**: New workload `healthcare-call-agent` is self-contained with its own `main.bicep` and environment parameters
- ✅ **Module Reusability**: Uses existing shared modules (storage-account, function-app, sql-database, application-insights) from `infra/modules/`
- ✅ **Infrastructure-as-Code Rigor**: 100% Bicep-defined; no imperative scripts; all resources version-controlled and repeatable
- ✅ **No Credentials in Version Control**: Connection strings and secrets passed at deployment time via GitHub Actions; no hardcoded values
- ✅ **Consistent Naming & Parameterization**: Follows `{resourceType}-{workloadName}-{environment}` pattern; environment-specific values in `.bicepparam` files

**Constitution Requirements**:
- Managed Identity will be implemented in Phase 2 (currently MVP uses SQL admin user; planned upgrade)
- Cross-RG referencing follows least-privilege: Service Principal has Reader on the shared RG and Contributor scoped only to the workload RG (`rg-healthcare-call-agent-prod`); if subscription-scope actions (e.g., RG creation) are required, use a minimal custom role instead of subscription-wide Contributor
- Key Vault RBAC compliance (Phase 2): Must use API 2026-02-01+ with `enableRbacAuthorization: true` by Feb 27, 2027

## Project Structure

### Infrastructure Code (IaC)

```text
infra/
├── modules/                          # Shared reusable components (existing)
│   ├── compute/
│   │   ├── app-service-plan.bicep   # (exists)
│   │   └── function-app.bicep       # ✅ USED: Functions App deployment
│   ├── config/
│   │   ├── app-configuration.bicep  # (exists)
│   │   └── key-vault.bicep          # (Phase 2: RBAC implementation)
│   ├── data/
│   │   ├── storage-account.bicep    # ✅ USED: Storage Account for Functions runtime
│   │   ├── cosmos-db.bicep          # (exists - not used in this feature)
│   │   ├── documentdb.bicep         # (exists - not used in this feature)
│   │   └── sql-database.bicep       # 🆕 NEW: SQL Database provisioning (to be created)
│   ├── identity/
│   │   └── user-assigned-identity.bicep  # (Phase 2: Managed Identity setup)
│   └── monitoring/
│       └── application-insights.bicep    # (Optional: Telemetry)
│
├── workloads/
│   └── healthcare-call-agent/            # ✅ NEW WORKLOAD (this feature)
│       ├── main.bicep                   # Subscription-scope orchestration
│       │                                # - Creates resource group
│       │                                # - Composes needed modules
│       │                                # - Queries shared resources
│       │                                # - Configures Functions App
│       │
│       └── environments/
│           ├── dev.bicepparam          # Development parameter file
│           ├── uat.bicepparam          # UAT parameter file
│           └── prod.bicepparam         # Production parameter file
│
└── bicepconfig.json                     # Linting rules (existing)
```

### Documentation Structure

```text
specs/001-call-agent-deploy/
├── spec.md                 # Feature specification (COMPLETED)
├── plan.md                 # This file (Phase 1 planning)
├── research.md             # Phase 0 research findings (to be created)
├── data-model.md           # Phase 1 data modeling (to be created)
├── quickstart.md           # Phase 1 deployment quickstart (to be created)
├── contracts/              # Phase 1 contract definitions (to be created)
└── tasks.md                # Phase 2 implementation tasks (generated by /speckit.tasks)
```

**New Artifacts to Create**:
1. `infra/modules/data/sql-database.bicep` - SQL Server and Database module (reusable, RG-scoped)
2. `infra/workloads/healthcare-call-agent/main.bicep` - Workload orchestration template (subscription scope)
3. `infra/workloads/healthcare-call-agent/environments/dev.bicepparam` - Dev parameters
4. `infra/workloads/healthcare-call-agent/environments/prod.bicepparam` - Prod parameters
5. `specs/001-call-agent-deploy/research.md` - Cross-RG referencing patterns and validation
6. `specs/001-call-agent-deploy/quickstart.md` - Step-by-step deployment guide
7. `.github/workflows/deploy-healthcare-call-agent.yml` - GitHub Actions CI/CD pipeline

## Complexity Tracking

No violations of cerebricep constitution detected. All design decisions align with workload-centric architecture and infrastructure-as-code rigor principles.
