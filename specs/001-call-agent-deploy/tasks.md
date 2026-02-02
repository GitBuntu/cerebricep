# Implementation Tasks: Healthcare Call Agent MVP - Cross-RG Infrastructure Deployment

**Feature**: Healthcare Call Agent MVP  
**Branch**: `001-call-agent-deploy`  
**Date**: February 2, 2026  
**Spec**: [specs/001-call-agent-deploy/spec.md](spec.md)

---

## Overview

**Total Tasks**: 36 (was 32; +4 from analysis recommendations)
**Phases**: 6 (Setup + Foundational + 4 User Stories + Polish)

| User Story | Task Count | Summary |
|------------|-----------|---------|
| US1 (P1): Deploy Infrastructure via IaC | 9 | Bicep templates, workload structure, parameter files, cross-RG queries, error handling |
| US2 (P1): Enable Cross-RG Referencing | 6 | Cross-RG query pattern, RBAC configuration, documentation |
| US3 (P2): Validate MVP Resource Sufficiency | 5 | Cost analysis, capacity planning, security checklist, runtime validation |
| US4 (P2): Deployment Guidance & Rollback | 7 | Deployment guide, validation, troubleshooting, rollback, cost monitoring |
| Setup/Foundational | 8 | Project structure, shared modules, GitHub Actions setup |

**Independent Test Criteria**:
- **US1**: Deployment completes in < 10 minutes; all resources created and tagged correctly; Functions App starts without errors
- **US2**: Service principal RBAC validates; ACS and AI Services properties queried successfully; audit logs show minimal cross-RG access
- **US3**: Cost breakdown < $10/month for new resources; capacity headroom ≥ 3x; security gaps documented with Phase 2 roadmap
- **US4**: Deployment guide followed end-to-end without ambiguities; validation commands confirm all resources accessible; rollback removes all resources cleanly

**Parallel Execution**: US1, US2, US3 can proceed in parallel after Foundational phase completes. US4 (documentation) depends on US1 completion for validation steps.

---

## Phase 1: Setup

- [ ] T001 Create workload directory structure `infra/workloads/healthcare-call-agent/`
- [ ] T002 Create workload main template `infra/workloads/healthcare-call-agent/main.bicep` (skeleton)
- [ ] T003 Create environment parameter files: `dev.bicepparam`, `uat.bicepparam`, `prod.bicepparam`
- [ ] T004 Create workload documentation file `infra/workloads/healthcare-call-agent/DEPLOYMENT-NOTES.md` (skeleton)

---

## Phase 2: Foundational (Blocking Prerequisites)

- [ ] T005 [P] Verify Azure SQL Database module exists or design new `infra/modules/data/sql-database.bicep`
- [ ] T006 [P] Document cross-RG referencing pattern in `infra/workloads/healthcare-call-agent/CROSS-RG-PATTERN.md` with working Bicep examples (Bicep `resourceId()` + `listConnectionStrings()`/`listKeys()` functions); include in code review validation checklist
- [ ] T007 [P] Update bicepconfig.json with any new linting rules for cross-RG patterns
- [ ] T008 Create GitHub Actions workflow template `.github/workflows/deploy-healthcare-call-agent.yml` (skeleton)

---

## Phase 3: User Story 1 (P1) - Deploy Infrastructure via IaC

**Goal**: Create all required Bicep templates and parameter files for healthcare-call-agent workload; workload is deployable and creates all infrastructure in a single command.

**Test Criteria**:
- Deployment completes in < 10 minutes: `az deployment sub create --location eastus2 --template-file infra/workloads/healthcare-call-agent/main.bicep --parameters infra/workloads/healthcare-call-agent/environments/dev.bicepparam`
- Resource Group `rg-healthcare-call-agent-prod` created with correct tags (workload=healthcare-call-agent, environment=prod, managedBy=IaC)
- Storage Account, SQL Server, Database, Functions App all exist and are accessible with correct names
- Functions App Application Settings include ACS connection string, AI Services endpoint, SQL connection string (from cross-RG queries)

### Implementation Tasks (US1)

- [ ] T009 [US1] Implement resource group creation in `infra/workloads/healthcare-call-agent/main.bicep` (subscription scope)
- [ ] T009.5 [P] [US1] Implement Bicep `listConnectionStrings()` and `listKeys()` functions to retrieve ACS connection string and AI Services endpoint from cross-RG resources; document error handling for missing resources
- [ ] T010 [P] [US1] Implement storage account module call in main.bicep using `infra/modules/data/storage-account.bicep`
- [ ] T011 [P] [US1] Implement SQL database module call in main.bicep using `infra/modules/data/sql-database.bicep`
- [ ] T012 [P] [US1] Implement user-assigned identity module call in main.bicep using `infra/modules/identity/user-assigned-identity.bicep`
- [ ] T013 [P] [US1] Implement function app module call in main.bicep using `infra/modules/compute/function-app.bicep`
- [ ] T014 [US1] Add cross-RG query for ACS resource from `rg-vm-prod-canadacentral-001` in main.bicep
- [ ] T015 [US1] Add cross-RG query for AI Services resource in main.bicep
- [ ] T016 [US1] Add module outputs for all created resources in main.bicep (resource IDs, connection strings, endpoints)
- [ ] T016.5 [US1] Implement error handling in Bicep for failed cross-RG resource queries; ensure clear error messages if ACS or AI Services resources not found in shared resource group (use `if()` condition + `error()` function)

---

## Phase 4: User Story 2 (P1) - Enable Cross-Resource-Group Referencing

**Goal**: Establish and document the pattern for querying shared resources across resource groups; GitHub Actions service principal has minimum required RBAC roles.

**Test Criteria**:
- Service principal has Reader role on `rg-vm-prod-canadacentral-001` and Contributor on subscription (verified via `az role assignment list`)
- Bicep template successfully retrieves ACS connection string and phone number from shared RG at deployment time
- Bicep template successfully retrieves AI Services endpoint from shared RG at deployment time
- Audit logs show cross-RG queries but no unnecessary elevated permissions

### Implementation Tasks (US2)

- [ ] T017 [P] [US2] Implement Bicep `resourceId()` function to reference ACS resource across RGs in main.bicep
- [ ] T018 [P] [US2] Implement Bicep `listConnectionStrings()` or equivalent to retrieve ACS connection string in main.bicep
- [ ] T019 [P] [US2] Implement Bicep `listKeys()` function to retrieve AI Services key in main.bicep
- [ ] T020 [US2] Document RBAC role assignments in `.github/workflows/deploy-healthcare-call-agent.yml` comments
- [ ] T021 [US2] Create RBAC validation checklist in `infra/workloads/healthcare-call-agent/DEPLOYMENT-NOTES.md`
- [ ] T022 [US2] Update agent context documentation with cross-RG pattern and security considerations

---

## Phase 5: User Story 3 (P2) - Validate MVP Resource Sufficiency

**Goal**: Confirm selected resources are sufficient for 100 calls/day and cost-effective (~$122/month total with shared resources); document capacity headroom and security gaps.

**Test Criteria**:
- Cost breakdown shows new resources < $10/month (Function App Consumption ~$0.20, SQL Basic ~$5, Storage ~$2)
- Capacity analysis confirms ≥ 3x headroom for 100 calls/day on each resource tier
- Security checklist identifies MVP vs. Phase 2 components (MVP: SQL firewall, HTTPS; Phase 2: Key Vault, VNet)
- No compliance violations for MVP scope

### Implementation Tasks (US3)

- [ ] T023 [P] [US3] Create cost analysis document in `specs/001-call-agent-deploy/cost-analysis.md` with resource breakdown
- [ ] T024 [P] [US3] Create capacity planning document in `specs/001-call-agent-deploy/capacity-planning.md` with headroom calculations
- [ ] T025 [US3] Document MVP security checklist in `specs/001-call-agent-deploy/security-checklist.md` (what IS protected)
- [ ] T026 [US3] Document Phase 2 security roadmap in `specs/001-call-agent-deploy/security-roadmap-phase2.md` (what WILL BE protected)
- [ ] T026.5 [US3] Create post-deployment monitoring task: measure actual monthly costs (first month) and resource capacity utilization; document variance vs. projections in `specs/001-call-agent-deploy/cost-analysis.md`

---

## Phase 6: User Story 4 (P2) - Deployment Guidance & Rollback Capability

**Goal**: Create step-by-step deployment guide, validation procedures, troubleshooting guide, and rollback procedures for operations teams.

**Test Criteria**:
- Operations engineer can follow deployment guide end-to-end without additional research
- Validation commands confirm all resources exist and are correctly configured
- Rollback procedure (`az group delete`) cleanly removes all resources without orphaned data
- Troubleshooting guide resolves common failure scenarios (missing RBAC, network issues, schema migration failures)

### Implementation Tasks (US4)

- [ ] T027 [US4] Create step-by-step deployment guide in `infra/workloads/healthcare-call-agent/DEPLOYMENT-NOTES.md`
- [ ] T028 [US4] Implement post-deployment validation script in `infra/workloads/healthcare-call-agent/validate-deployment.ps1` (PowerShell)
- [ ] T029 [P] [US4] Create troubleshooting guide in `specs/001-call-agent-deploy/troubleshooting.md`
- [ ] T030 [P] [US4] Document rollback procedure in `infra/workloads/healthcare-call-agent/DEPLOYMENT-NOTES.md`
- [ ] T031 [US4] Create pre-deployment checklist in `specs/001-call-agent-deploy/pre-deployment-checklist.md`
- [ ] T032 [US4] Update `.github/workflows/deploy-healthcare-call-agent.yml` with deployment success/failure notifications
- [ ] T032.5 [US4] Implement Azure budget alert in GitHub Actions workflow to notify if monthly costs exceed $10/month threshold for new resources; document in DEPLOYMENT-NOTES.md

---

## Phase 7: Polish & Cross-Cutting Concerns

*(No additional tasks beyond above. All cross-cutting concerns addressed in respective user story phases.)*

---

## Dependencies & Execution Order

### Blocking Sequence
1. **Phase 1** (Setup) → Phase 2 (Foundational) → Phases 3-6
2. **Phase 2** (Foundational) is blocking for all user story phases
3. **Phases 3 & 4** (US1, US2) can execute in parallel; both depend on Phase 2
4. **Phases 5 & 6** (US3, US4) can execute in parallel; Phase 6 light-depends on Phase 3 for validation criteria

### Recommended Execution (Sequential with Parallel Options)
```
Setup (T001-T004)
  ↓
Foundational (T005-T008)
  ├─→ US1 (T009-T016) ──┐
  ├─→ US2 (T017-T022)   ├→ Merge → Integrated Testing
  ├─→ US3 (T023-T026)   │
  └─→ US4 (T027-T032) ──┘
```

### Parallel Execution Example (Optimal for 4-person team)
- **Person A**: T009-T016 (US1 core Bicep templates)
- **Person B**: T017-T022 (US2 cross-RG queries + RBAC docs)
- **Person C**: T023-T026 (US3 cost & capacity analysis)
- **Person D**: T027-T032 (US4 deployment guides)
- **All**: Integrated testing after Phase 2 merge

---

## MVP Scope & Future Phases

**MVP** (Current): US1 + US2 + US3 + US4 = Complete IaC deployment with documentation  
**Phase 2** (Future): Security hardening (Key Vault, VNet, private endpoints, HTTPS enforcement, Application Insights)  
**Phase 3** (Future): Advanced observability (custom alerting, cost optimization, multi-region support)

---

## Success Criteria Summary

| Phase | Outcome | Verification |
|-------|---------|--------------|
| Phase 1 | Workload directory structure ready | Directory listing shows all required files |
| Phase 2 | Foundational templates available | Bicep build succeeds on main.bicep |
| Phase 3 (US1) | Infrastructure deployable | `az deployment sub create` completes in < 10 min |
| Phase 4 (US2) | Cross-RG queries functional | ACS + AI Services properties injected correctly |
| Phase 5 (US3) | Resource validation complete | Cost < $10/month, capacity ≥ 3x headroom |
| Phase 6 (US4) | Operations ready | Deployment guide followed without ambiguity; rollback successful |

