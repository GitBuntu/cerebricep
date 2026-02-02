# Phase 0: Research & Clarifications

**Date Generated**: February 2, 2026  
**Status**: In Progress → Pending Research Agent Execution  
**Scope**: Resolve all NEEDS CLARIFICATION items from Technical Context and Implementation Plan

---

## Research Tasks

### Task 1: Cross-Resource-Group (Cross-RG) Referencing Pattern in Bicep

**Research Question**: How can Bicep templates query and reference resources from a different resource group (shared RG) while deploying to a separate application RG?

**Context**: Feature requires healthcare-call-agent workload to reference shared Azure Communication Services (ACS) and Azure AI Services from `rg-vm-prod-canadacentral-001` and use their connection strings in the new workload's Function App deployed to a new application resource group.

**Decision Needed**:
- [ ] Is `resourceId()` function sufficient to retrieve resource IDs across RGs?
- [ ] How to retrieve connection strings and keys from shared resources using Bicep?
- [ ] Should queries happen at deployment time (via Azure CLI in template) or pre-deployment (via script)?
- [ ] What RBAC roles are required for GitHub Actions service principal on shared RG?
- [ ] Are there security implications or audit log concerns?

**Success Criteria**:
- Pattern documented with working example
- RBAC permission matrix defined
- Security considerations identified

---

### Task 2: Azure SQL Database Module Design

**Research Question**: Does a reusable `sql-database.bicep` module already exist in the project? If not, what should it contain?

**Context**: Feature specification mentions SQL Database as a required resource for the MVP. The project has established module patterns in `infra/modules/data/`.

**Decision Needed**:
- [ ] Search existing modules to confirm if `sql-database.bicep` exists
- [ ] If exists: What parameters does it accept? Does it support cross-RG scenarios?
- [ ] If missing: Design module following cerebricep conventions (location, tags, parameters, outputs)
- [ ] Should module handle both single database and elastic pool scenarios?
- [ ] What firewall rules should be default? (e.g., allow Azure services)

**Success Criteria**:
- [ ] Module path and capabilities documented OR
- [ ] Design specification for new module with parameters, outputs, and security defaults

---

### Task 3: GitHub Actions RBAC Configuration for Cross-RG Deployment

**Research Question**: What are the minimum required Azure RBAC roles for GitHub Actions service principal to deploy healthcare-call-agent while respecting cross-RG access patterns?

**Context**: GitHub Actions needs to authenticate to Azure, read from shared RG (e.g., `{SHARED_RG_NAME}`), and deploy to application RG (e.g., `rg-healthcare-call-agent-{env}`).

**Decision Needed**:
- [ ] What role(s) on shared RG? (Reader? Custom role? Specific resource access?)
- [ ] What role(s) on app RG? (Contributor? Specific Bicep actions only?)
- [ ] What role(s) at subscription level? (None? Resource Group Creator?)
- [ ] How to configure least-privilege access?
- [ ] How to validate permissions are sufficient before production deployment?

**Success Criteria**:
- [ ] RBAC role matrix documented
- [ ] Rationale for each role assignment
- [ ] Deployment validation checklist

---

### Task 4: MVP Cost Analysis & Resource Validation

**Research Question**: Are the selected MVP resources (Function App, SQL Database, Storage Account, + shared ACS/AI Services) sufficient for 100 calls/day and cost-effective (~$122/month)?

**Context**: Feature specification claims ~$122/month for new resources + pre-existing shared infrastructure. Need to validate capacity headroom and cost breakdown.

**Decision Needed**:
- [ ] Function App tier (Consumption, Premium)? Cold start impact?
- [ ] SQL Database SKU (S0, S1, serverless)? Pricing for 100 calls/day?
- [ ] Storage Account tier (Standard, Premium)? Estimated usage?
- [ ] Total monthly cost for new resources?
- [ ] What capacity headroom exists for growth?
- [ ] Which resources are cost-critical for MVP?

**Success Criteria**:
- [ ] Cost breakdown by resource with justification
- [ ] Capacity analysis for 100 calls/day + 3x headroom
- [ ] Cost escalation path documented for Phase 2

---

### Task 5: Security Hardening Roadmap (Phase 2 Deferral Justification)

**Research Question**: Why are Key Vault, VNet, and private endpoints deferred to Phase 2? What is the migration path?

**Context**: Feature spec explicitly defers security hardening. Need to document why MVP can proceed without these and how Phase 2 will add them without major refactoring.

**Decision Needed**:
- [ ] What are the current (MVP) security gaps?
- [ ] What is the business risk of MVP without Key Vault, VNet, private endpoints?
- [ ] How will Phase 2 retrofit these components?
- [ ] Will Phase 2 require template refactoring?
- [ ] What compliance implications exist for MVP?

**Success Criteria**:
- [ ] MVP security checklist (what IS protected)
- [ ] Phase 2 security roadmap (what WILL BE protected)
- [ ] No compliance violations for MVP scope
- [ ] Migration plan from MVP to Phase 2 hardened state

---

## Research Agent Dispatch (Pending Execution)

Each task above will be researched by a subagent and consolidated into findings below.

### Research Findings (To Be Updated)

#### Finding 1: Cross-RG Bicep Pattern
**Decision**: [TO BE RESEARCHED]  
**Rationale**: [TO BE RESEARCHED]  
**Alternatives Considered**: [TO BE RESEARCHED]

#### Finding 2: SQL Database Module Status
**Decision**: [TO BE RESEARCHED]  
**Rationale**: [TO BE RESEARCHED]  
**Alternatives Considered**: [TO BE RESEARCHED]

#### Finding 3: GitHub Actions RBAC Configuration
**Decision**: [TO BE RESEARCHED]  
**Rationale**: [TO BE RESEARCHED]  
**Alternatives Considered**: [TO BE RESEARCHED]

#### Finding 4: MVP Cost & Capacity Analysis
**Decision**: [TO BE RESEARCHED]  
**Rationale**: [TO BE RESEARCHED]  
**Alternatives Considered**: [TO BE RESEARCHED]

#### Finding 5: Security Hardening Roadmap
**Decision**: [TO BE RESEARCHED]  
**Rationale**: [TO BE RESEARCHED]  
**Alternatives Considered**: [TO BE RESEARCHED]

---

## Gate: Transition to Phase 1

- [ ] All research questions answered
- [ ] All findings documented with decision + rationale
- [ ] Constitution Check re-evaluated (post-design)
- [ ] Technical Context updated with research results
- [ ] Ready to create data-model.md and contracts/

**Status**: Awaiting research agent results → Phase 1 design phase will begin once all findings consolidated.
