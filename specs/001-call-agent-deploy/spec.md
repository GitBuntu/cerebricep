# Feature Specification: Healthcare Call Agent MVP - Cross-RG Infrastructure Deployment

**Feature Branch**: `001-call-agent-deploy`  
**Created**: January 31, 2026  
**Status**: Draft  
**Input**: User description: "Create cross-RG IaC deployment for Healthcare Call Agent MVP with shared Azure Communication Services and new app resources in separate resource groups"

---

## Executive Summary

Deploy a production-ready Healthcare Call Agent MVP using a hybrid cloud architecture that **reuses existing shared infrastructure** (Azure Communication Services + Azure AI Services) while creating isolated application resources. The deployment follows an **enterprise cross-resource-group pattern** where shared infrastructure remains centralized and application-specific resources are housed in a separate resource group, eliminating cost duplication and simplifying Infrastructure-as-Code (IaC) management.

**Key Value**:
- ✅ Minimal monthly cost (~$122 total; **new resources ~$6–10/month**, shared ACS/AI Services ~$112/month)
- ✅ Enterprise-grade architecture pattern (shared + app-specific resource isolation)
- ✅ Production-ready within 2 hours of deployment
- ✅ Clear path to security hardening (Key Vault, VNet scheduled for Phase 2)

**Cost Breakdown**:
| Component | Estimated Cost | Notes |
|-----------|----------------|-------|
| New Azure Functions (Consumption) | ~$0.20 | Free tier for 100 calls/day |
| New SQL Database (Basic tier) | ~$5.00 | 5 DTU, sufficient for MVP |
| New Storage Account | ~$2.00 | Standard V2 with LRS |
| **Subtotal: New Resources** | **~$7.20/month** | Scales with usage |
| Shared ACS (phone minutes) | ~$112/month | Pre-existing; reused across workloads |
| Shared AI Services | ~$0/month | Bundled with ACS; marginal cost |
| **TOTAL MONTHLY** | **~$119/month** | Dominated by pre-existing ACS |

*Cost estimates based on Azure pricing as of Feb 2026; verify in Azure Pricing Calculator*

---

## User Scenarios & Testing

### User Story 1 - Deploy Infrastructure via IaC (Priority: P1)

**Role**: DevOps Engineer / Cloud Infrastructure Team

Operations teams need to provision the complete Healthcare Call Agent infrastructure in a repeatable, version-controlled, and auditable manner. The deployment must query existing shared resources from another resource group, inject those values into new application resources, and ensure all networking and security boundaries are correctly established.

**Why this priority**: This is the foundational capability—without working IaC, the entire MVP cannot be deployed or maintained. All other features depend on infrastructure being available and correctly configured.

**Independent Test**: This story can be validated independently by executing the IaC deployment pipeline in a clean Azure subscription and verifying that:
1. New resource group `rg-healthcare-call-agent-prod` is created
2. Storage Account, SQL Database, and Functions App are provisioned
3. Configuration values from shared resources are correctly queried and injected
4. All resources are accessible and ready for application code deployment

**Acceptance Scenarios**:

1. **Given** a clean Azure subscription with GitHub Actions service principal configured, **When** the IaC deployment is triggered, **Then** resource group `rg-healthcare-call-agent-prod` and all 4-5 new resources are created in ~10 minutes with no manual configuration required

2. **Given** shared resources exist in `rg-vm-prod-canadacentral-001` (ACS + AI Services with configured phone number), **When** IaC queries these resources, **Then** connection strings and endpoints are correctly retrieved and injected into Functions App Application Settings without requiring manual copy-paste

3. **Given** SQL Database firewall is configured during deployment, **When** Azure Functions attempts to connect to the database, **Then** the connection succeeds without timeout or authentication errors

4. **Given** Functions App is configured with ACS connection string, **When** the call initiation endpoint is invoked, **Then** the Functions App successfully authenticates with ACS and returns a valid call session ID

5. **Given** all infrastructure is deployed, **When** a developer reviews the Azure Portal, **Then** the resource hierarchy, tags, and naming conventions match the IaC template design

---

### User Story 2 - Enable Cross-Resource-Group Referencing (Priority: P1)

**Role**: Cloud Architect / Security Team

Architecture teams need to establish and document the pattern for referencing existing shared infrastructure resources from a different resource group. This pattern must be secure (minimum required permissions), repeatable, and observable in audit logs for compliance purposes.

**Why this priority**: This directly enables the cost-optimization benefit of the feature (no duplication of expensive ACS resources). Without proper cross-RG referencing, teams would provision duplicate infrastructure, doubling costs and creating governance headaches.

**Independent Test**: This story is validated by:
1. Verifying the GitHub Actions service principal has exactly the required RBAC roles (no over-provisioning)
2. Confirming that IaC can retrieve properties from shared resource group without manual intervention
3. Validating that the pattern is documented and replicable for future shared resources

**Acceptance Scenarios**:

1. **Given** service principal has Reader role on shared RG but Contributor on application RG, **When** IaC executes, **Then** it can read ACS/AI Services properties from shared RG AND create resources in app RG without requiring elevation

2. **Given** ACS or AI Services resources are queried via Azure CLI commands in IaC, **When** the commands execute, **Then** results are captured and available for injection into new resource Application Settings

3. **Given** production security audit requirements, **When** access logs are reviewed, **Then** only necessary queries to shared RG are visible (no unnecessary cross-RG reads)

4. **Given** the pattern is documented, **When** a new DevOps team member reviews the IaC code, **Then** they understand why cross-RG referencing is used and when it should apply to future resources

---

### User Story 3 - Validate MVP Resource Sufficiency (Priority: P2)

**Role**: Product Manager / Technical Lead

Product leadership needs confidence that the selected resources (Functions, SQL, Storage, ACS, AI Services) are both necessary and sufficient for MVP functionality. Over-provisioning increases costs unnecessarily; under-provisioning causes delays and poor user experience.

**Why this priority**: This validates that the YAGNI (You Aren't Gonna Need It) principle is applied correctly. Resources like Key Vault, VNet, and Premium Application Insights are deferred by design, not by accident, and the rationale must be clear and documented.

**Independent Test**: This story is tested by:
1. Creating a deployment plan document that justifies each resource choice
2. Identifying resources explicitly deferred (with upgrade path documented)
3. Confirming that MVP can handle the target load (100 calls/day)
4. Validating that the planned cost (~$122/month) is acceptable

**Acceptance Scenarios**:

1. **Given** the MVP targets 100 calls/day (~1.4 concurrent calls average, ~5 concurrent peak), **When** resource capacity is calculated, **Then** all selected resources have sufficient capacity headroom ≥ 3x peak load (i.e., handle 15 concurrent calls maximum during MVP phase; headroom for 5x growth before tier upgrade needed)

2. **Given** security requirements for MVP, **When** security checklist is reviewed, **Then** critical items (SQL firewall, HTTPS enforcement) are implemented and non-critical items (Key Vault, VNet) are documented for Phase 2 with compliance requirements (Key Vault must use Azure RBAC with the latest stable Key Vault ARM API version supported at deployment time, in alignment with the official Azure Key Vault retirement announcements (see [official Azure Key Vault retirement guidance]({LINK_TO_OFFICIAL_AZURE_KEY_VAULT_RETIREMENT_NOTICE})))

3. **Given** cost constraints, **When** the cost breakdown is reviewed, **Then** the new infrastructure costs < $10/month and existing shared resources are leveraged to minimize total spend

4. **Given** Azure Functions cold start performance is a concern, **When** startup latency is measured, **Then** it is < 3 seconds for MVP use cases (upgrade to Premium tier if needed post-launch)

---

### User Story 4 - Provide Deployment Guidance & Rollback Capability (Priority: P2)

**Role**: Operations / Site Reliability Engineer

Operations teams need clear step-by-step guidance for executing the deployment, validating that it succeeded, and rolling back if necessary. Additionally, they need troubleshooting guides for common failure scenarios and diagnostic commands.

**Why this priority**: Deployment execution and post-deployment validation are critical for launch readiness. Clear guidance reduces manual errors and incidents. Rollback capability ensures we can recover from failed deployments without data loss.

**Independent Test**: This story is validated by:
1. Following the deployment guide end-to-end in a test environment without deviation
2. Executing all validation commands and confirming expected outcomes
3. Documenting any ambiguities or missing steps
4. Testing rollback procedures to ensure clean resource deletion

**Acceptance Scenarios**:

1. **Given** the deployment guide, **When** an operations engineer follows it step-by-step, **Then** they complete the deployment successfully without requiring additional research or asking for clarification

2. **Given** deployment is complete, **When** validation commands are executed, **Then** they confirm all resources exist, are accessible, and are correctly configured

3. **Given** a deployment fails mid-execution, **When** a rollback is needed, **Then** `az group delete --name {RESOURCE_GROUP_NAME}` removes all resources without orphaned data or costs

4. **Given** common failure scenarios (e.g., service principal missing Reader role), **When** a troubleshooting guide is consulted, **Then** the issue is identified and resolved without escalation

---

## Functional Requirements

### Core Infrastructure Requirements

#### FR-1: Create Application Resource Group
- The system **must** create a new Azure Resource Group named `rg-healthcare-call-agent-prod` in East US 2 region
- The resource group **must** use consistent tagging (workload=healthcare-call-agent, environment=prod, managedBy=IaC)
- The resource group **must** be created idempotently (re-running deployment doesn't fail if RG already exists)
- The resource group **must** serve as the logical container for all application-specific resources
- **Acceptance Criteria**: `az group show --name rg-healthcare-call-agent-prod` returns the resource group with correct tags

#### FR-2: Query Existing Shared Resources
- The system **must** query Azure Communication Services resource from shared resource group (resource name provided at deployment time)
- The system **must** retrieve the ACS connection string without requiring manual entry
- The system **must** retrieve the ACS phone number (e.g., `{ACS_PHONE_NUMBER}` from shared resource) for injection into Functions configuration
- The system **must** query Azure AI Services resource from the same shared resource group (resource name provided at deployment time)
- The system **must** retrieve the AI Services endpoint URL for text-to-speech functionality
- **Acceptance Criteria**: Azure CLI command to query ACS resource successfully returns connection string (exact command format documented in deployment guide)

#### FR-3: Provision Azure Storage Account
- The system **must** create a Standard StorageV2 account named `sthealthcarecaprod` with LRS replication
- Storage account **must** be created in East US 2 region (same as app resources)
- Storage account **must** serve as the required backing store for Azure Functions runtime
- Storage account **must** support Queue, Table, and Blob storage for Functions bindings
- **Acceptance Criteria**: Functions App startup doesn't fail with storage account unavailability errors

#### FR-4: Provision Azure Functions App
- The system **must** create a Function App named `func-healthcare-call-agent-prod` using Consumption Plan pricing model
- The Function App **must** use .NET 9 runtime in isolated worker process mode
- The Function App **must** be deployed on Linux OS for cost optimization
- The Function App **must** be associated with the Storage Account created in FR-3
- The Function App **must** accept HTTP-triggered function endpoints for call management
- **Acceptance Criteria**: `func azure functionapp publish func-healthcare-call-agent-prod` successfully deploys code to the app

#### FR-5: Provision Azure SQL Database
- The system **must** create Azure SQL Server named `sql-healthcare-call-agent-prod` with admin authentication
- The system **must** create a database named `HealthcareCallAgentDb` on the SQL server
- The SQL Database **must** be provisioned at Basic tier (5 DTU) for MVP load requirements
- The SQL Database **must** have firewall rules configured to allow Azure services (required for Functions connectivity)
- The SQL Database **must** support Entity Framework Core migrations for schema creation
- **Acceptance Criteria**: `dotnet ef database update` successfully creates CallSessions and CallResponses tables

#### FR-6: Configure Functions App Application Settings
- The system **must** inject the ACS connection string into Functions App setting `AzureCommunicationServices__ConnectionString`
- The system **must** inject the ACS phone number into Functions App setting `AzureCommunicationServices__PhoneNumber`
- The system **must** inject the Functions webhook callback URL into `AzureCommunicationServices__CallbackUrl`
- The system **must** inject the AI Services endpoint into `AzureCommunicationServices__CognitiveServicesEndpoint`
- The system **must** inject the SQL Database connection string into `ConnectionStrings__HealthcareCallAgentDb`
- The system **must** store connection strings as application settings (not in files checked into source control)
- **Acceptance Criteria**: Running `az functionapp config appsettings list --name func-healthcare-call-agent-prod --resource-group rg-healthcare-call-agent-prod` shows all configured settings with correct values

#### FR-7: Optional Application Insights Integration
- The system **should** offer the option to create Application Insights for telemetry and diagnostics
- If enabled, Application Insights **must** be named `appi-healthcare-call-agent-prod` and created in East US 2
- Application Insights **must** remain optional for MVP (not a hard requirement)
- **Acceptance Criteria**: Application Insights creation is a separate, optional IaC step

#### FR-8: Enable SQL Database Connectivity from Azure
- The system **must** configure SQL Server firewall rule to allow connections from Azure services
- The rule **must** use the standard Azure Services rule (0.0.0.0 to 0.0.0.0 in Azure portal terms)
- **Acceptance Criteria**: `az sql server firewall-rule create` successfully creates the allow rule without errors

### Cross-Resource-Group Integration Requirements

#### FR-9: Service Principal RBAC Configuration
- Service principal **must** have Contributor role on Azure subscription (for creating new resources)
- Service principal **must** have Reader role on `rg-vm-prod-canadacentral-001` (for querying shared resources)
- Service principal **must** NOT have higher permissions than necessary (principle of least privilege)
- **Acceptance Criteria**: `az role assignment list --assignee <sp-object-id>` shows Contributor (subscription scope) and Reader (shared RG scope)

#### FR-10: Secure Parameter Passing
- Sensitive values (connection strings, passwords) **must not** be logged to console output
- Sensitive values **must** be masked in GitHub Actions logs using `::add-mask::`
- Parameter injection **must** occur only at deployment time (not baked into templates)
- **Acceptance Criteria**: GitHub Actions workflow logs show masked output for sensitive settings

### Data Persistence & Schema Requirements

#### FR-11: SQL Database Schema Initialization
- The system **must** support Entity Framework Core migrations for automatic schema creation
- Migrations **must** create `CallSessions` table with columns: SessionId (PK), MemberId (FK), PhoneNumber, Status, StartTime, EndTime
- Migrations **must** create `CallResponses` table with columns: ResponseId (PK), SessionId (FK), Action, Timestamp
- Migrations **must** create appropriate indexes on frequently-queried columns (MemberId, Status, CallConnectionId, StartTime)
- **Acceptance Criteria**: `dotnet ef database update` completes without errors and schema is visible in Azure Portal

#### FR-12: Connection String Management
- The system **must** pass SQL connection string to Functions App via Application Settings (MVP temporary approach)
- The connection string **must** use Managed Identity authentication path for future security upgrade
- The connection string format **must** be compatible with Entity Framework Core connection string parser
- **Acceptance Criteria**: Functions App can establish connection and execute queries without authentication errors

---

## Success Criteria

### Deployment Completeness
- ✅ All 4 required new resources (RG, Storage, Functions, SQL) are successfully created within 15 minutes of IaC execution
- ✅ All configuration values from shared resources are correctly queried and injected (verified via Portal)
- ✅ No manual configuration steps are required after IaC completes (only code deployment remains)
- ✅ Resource naming follows enterprise conventions (resource-type-workload-environment format)

### Functional Readiness
- ✅ Azure Functions App is accessible and ready to receive code deployment
- ✅ SQL Database schema is created and ready for application data
- ✅ Functions App can successfully authenticate with ACS using injected connection string
- ✅ Functions App can successfully authenticate with AI Services using injected endpoint
- ✅ SQL Database allows inbound connections from Functions App (firewall configured)

### Cost Optimization
- ✅ Total new infrastructure cost is < $6/month (current: Storage $0.02 + SQL $5 = $5.02)
- ✅ Existing shared resources are reused (no cost duplication for ACS/AI Services)
- ✅ Consumption Plan functions pricing remains in free tier for target 100 calls/day

### Security & Compliance (MVP Level)
- ✅ SQL Database firewall restricts access to Azure services only (no public internet exposure)
- ✅ Functions App enforces HTTPS for all endpoints
- ✅ No credentials are logged or exposed in GitHub Actions output (masked)
- ✅ Service principal has minimum required permissions (Reader on shared RG + Contributor on subscription)
- ✅ Connection strings are stored in Functions App Application Settings (acceptable for MVP, planned upgrade to Key Vault in Phase 2)

### Operational Readiness
- ✅ Step-by-step deployment guide exists and can be followed without clarification
- ✅ Post-deployment validation checklist confirms all resources are accessible
- ✅ Troubleshooting guide covers top 5 failure scenarios and diagnostic commands
- ✅ Rollback procedure is tested and documented (clean deletion with no orphaned resources)

---

## Key Entities & Data Models

### Resource Entity Model

```
ResourceGroup (rg-healthcare-call-agent-prod)
├── Identifier: Resource Group Name
├── Properties: Location (East US 2), Tags (workload, environment, managedBy)
└── Contains:
    ├── StorageAccount (sthealthcarecaprod)
    │   ├── Type: StorageV2
    │   ├── Replication: LRS
    │   └── Used By: Azure Functions runtime
    │
    ├── FunctionApp (func-healthcare-call-agent-prod)
    │   ├── Plan Type: Consumption
    │   ├── Runtime: .NET 9 isolated
    │   ├── Configuration:
    │   │   ├── ACS ConnectionString (from shared RG)
    │   │   ├── ACS Phone Number (retrieved from shared ACS resource at deployment time)
    │   │   ├── AI Services Endpoint (from shared RG)
    │   │   └── SQL ConnectionString (new)
    │   └── Endpoints:
    │       ├── POST /api/calls/initiate/{memberId}
    │       ├── POST /api/calls/events (webhook)
    │       └── GET /api/calls/status/{sessionId}
    │
    ├── SqlServer (sql-healthcare-call-agent-prod)
    │   ├── AdminUser: sqladmin
    │   ├── Firewall: Allow Azure Services
    │   └── Database: HealthcareCallAgentDb
    │       ├── Table: CallSessions
    │       │   ├── SessionId (PK, GUID)
    │       │   ├── MemberId (FK, INT)
    │       │   ├── PhoneNumber (STRING)
    │       │   ├── Status (STRING: Initiated, InProgress, Completed, Failed)
    │       │   ├── StartTime (DATETIME)
    │       │   ├── EndTime (DATETIME, nullable)
    │       │   └── Indexes: MemberId, Status, StartTime
    │       │
    │       └── Table: CallResponses
    │           ├── ResponseId (PK, GUID)
    │           ├── SessionId (FK, GUID)
    │           ├── Action (STRING: MenuOption, TransferRequested, Hangup)
    │           ├── Timestamp (DATETIME)
    │           └── Index: SessionId, Timestamp
    │
    └── ApplicationInsights (appi-healthcare-call-agent-prod) [OPTIONAL]
        ├── Instrumentation Key
        └── Used for: Telemetry & Diagnostics (optional for MVP)

SharedResourceGroup ({SHARED_RG_NAME}) - EXTERNAL REFERENCE
├── AzureCommunicationServices ({ACS_RESOURCE_NAME} [shared across workloads])
│   ├── Phone Number: Retrieved at deployment time from shared resource
│   └── ConnectionString: [queried by IaC, passed to Functions]
│
└── AzureAiServices ({AI_SERVICES_RESOURCE_NAME})
    └── Endpoint: [queried by IaC, passed to Functions]
```

### Configuration Entity Model

```
FunctionsAppConfiguration
├── Source: Infrastructure-as-Code (queried at deployment time)
├── Settings Injected:
│   ├── AzureCommunicationServices__ConnectionString
    │   ├── Source: Queried from shared ACS resource at deployment time
    │   ├── Format: "endpoint=https://...; accesskey=..."
│   │   └── Scope: Used for all ACS call operations
│   │
│   ├── AzureCommunicationServices__PhoneNumber
    │   ├── Source: Queried from shared ACS resource at deployment time
    │   ├── Value: `{RETRIEVED_FROM_ACS_RESOURCE}` (e.g., +1-###-###-####)
│   │   └── Scope: Used for outbound PSTN calls
│   │
│   ├── AzureCommunicationServices__CognitiveServicesEndpoint
    │   ├── Source: Queried from shared AI Services resource at deployment time
    │   ├── Format: "https://{AI_SERVICES_NAME}.cognitiveservices.azure.com/"
│   │   └── Scope: Used for text-to-speech synthesis
│   │
│   ├── AzureCommunicationServices__CallbackUrl
    │   ├── Source: Generated from Functions App domain name at deployment time
    │   ├── Value: `https://{FUNCTIONS_APP_DOMAIN}/api/calls/events` (e.g., https://func-healthcare-call-agent-prod.azurewebsites.net/api/calls/events)
│   │   └── Scope: Configured in ACS for webhook events
│   │
│   └── ConnectionStrings__HealthcareCallAgentDb
│       ├── Source: Created during SQL Database provisioning
│       ├── Format: "Server=tcp:sql-healthcare-call-agent-prod.database.windows.net,1433;..."
│       ├── Authentication: SQL user (sqladmin, MVP); Managed Identity (planned for Phase 2)
│       └── Scope: Used for Entity Framework Core connection
│
└── Storage: Azure Functions Application Settings (temporary for MVP)
    └── Future Upgrade (Phase 2): Azure Key Vault with Azure RBAC (using the latest supported/stable Key Vault ARM API version at deployment time; see Azure Key Vault change log: https://learn.microsoft.com/azure/key-vault/general/change-log) and Managed Identity access
```

---

## Assumptions

1. **Azure Subscription Access**: Deployment assumes access to Azure subscription with sufficient quota for new resources
2. **Shared Resource Existence**: Deployment assumes shared ACS and AI Services resources already exist in designated shared resource group (exact resource names and group provided at deployment time)
3. **Service Principal Configuration**: GitHub Actions service principal is pre-configured with Contributor (subscription) + Reader (shared RG) roles
4. **SQL Admin Password Security**: SQL admin password is provided securely (e.g., via GitHub Actions secret, not in template)
5. **MVP Load Profile**: System is designed for 100 calls/day MVP load; scaling to 500+ calls/day requires SQL tier upgrade
6. **East US 2 Region**: Deployment is optimized for East US 2 region; other regions may have different pricing/availability
7. **Entity Framework Core**: Application codebase uses Entity Framework Core 9+ for ORM and migrations
8. **Temporary Secrets Storage**: MVP stores connection strings in Functions App settings (acceptable for testing); production requires Key Vault
9. **HTTPS Enforcement**: Functions App is configured for HTTPS-only (security best practice)
10. **No VNet Isolation**: MVP does not implement VNet or Private Endpoints (scheduled for production hardening phase)

---

## Constraints & Dependencies

### Constraints
- **MVP Cost Cap**: Infrastructure must stay under $10/month for new resources
- **Deployment Time**: Infrastructure provisioning must complete in < 20 minutes
- **Cross-RG Access**: Service principal must have exactly required permissions (no over-provisioning); evaluate whether Contributor scope can be limited to resource group instead of subscription level (Phase 2 security hardening)
- **SQL Tier**: Basic tier is maximum for MVP (2 GB max, 5 DTU); upgrade required for higher load
- **Functions Runtime**: .NET 9 only (no Node.js/Python/Java for this MVP)
- **No High Availability**: Single-region deployment (no failover for MVP)

### Dependencies
- **Shared Resources**: Deployment depends on existing ACS and AI Services in `rg-vm-prod-canadacentral-001`
- **Azure CLI 2.60+**: IaC requires modern Azure CLI with Bicep support
- **GitHub Actions Service Principal**: Deployment requires pre-configured service principal with RBAC roles
- **Entity Framework Core**: Application code must support EF Core migrations for SQL schema
- **HTTPS Certificate**: Functions App must have valid SSL certificate (provided by Azure automatically)

---

## Out of Scope (Deferred to Future Phases)

### Phase 2 - Security Hardening
- [ ] Azure Key Vault implementation using Azure RBAC (using the latest stable/supported Key Vault ARM API version available at deployment time and aligned with Microsoft's published Key Vault API retirement guidance)
  - [ ] Deploy Key Vault with `enableRbacAuthorization: true`
  - [ ] Assign RBAC roles (Key Vault Secrets Officer, Key Vault Secrets User) to managed identities
  - [ ] Migrate connection strings from Functions App settings to Key Vault
  - [ ] Validate deployment uses a currently supported Key Vault API version and complies with the official Azure Key Vault API retirement timeline as documented on Microsoft Learn
- [ ] Virtual Network (VNet) with private subnets
- [ ] Network Security Groups (NSGs) for access control
- [ ] Private Endpoints for SQL Database and Key Vault
- [ ] Azure Managed Identity (future planned)
- [ ] Azure Policy for compliance enforcement
- [ ] Automated backups and disaster recovery

### Phase 3 - Advanced Monitoring
- [ ] Application Insights integration (optional for MVP, included if needed)
- [ ] Advanced diagnostics and alerting
- [ ] Cost analysis and optimization tracking
- [ ] Performance baselines and SLO monitoring

### Phase 4 - Scale & Performance
- [ ] Functions Premium tier (if cold start becomes issue)
- [ ] SQL Database Standard tier S0 or higher (if load exceeds 500 calls/day)
- [ ] Database read replicas for scalability
- [ ] Content Delivery Network (CDN) for API responses (if latency becomes issue)

### Out of Scope (Not Planned)
- [ ] Kubernetes or container orchestration
- [ ] Multi-region failover
- [ ] Advanced CI/CD pipelines (GitHub Actions integration is basic)
- [ ] Custom domain names (using Azure-provided domains for MVP)

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| **Service Principal RBAC misconfiguration** | Medium | High | Pre-validate RBAC roles before deployment; include role check in validation script |
| **Cross-RG ACS/AI Services query fails** | Low | High | Document exact resource names; provide diagnostic command for verification |
| **SQL Database connection timeout** | Low | Medium | Include firewall rule explicitly; document connection pool sizing |
| **Functions App cold start > 3s** | Medium | Low | Acceptable for MVP; document upgrade path to Premium tier if needed |
| **Deployment takes > 20 minutes** | Low | Medium | Parallel resource creation; monitor Azure status page for service issues |
| **Cost escalation from ACS overages** | Medium | Medium | Monitor PSTN call minutes; implement cost alerts in Azure Monitor |
| **Secrets exposed in GitHub Actions logs** | Low | Critical | Use `::add-mask::` for sensitive values; enforce log masking in CI/CD |

---

## Testing Strategy

### Unit-Level Validation
1. **Bicep Template Validation**: `az bicep build --file main.bicep` passes without warnings
2. **Parameter Validation**: `az bicep build-params --file *.bicepparam` validates parameter schema

### Integration Testing
1. **Cross-RG Query Test**: Execute Azure CLI commands to retrieve ACS/AI Services properties from shared RG
2. **RBAC Validation Test**: Verify service principal can read shared RG and create resources in app RG
3. **Connectivity Test**: Execute test queries from deployed Functions App to SQL Database

### End-to-End Validation
1. **Resource Existence Check**: Verify all 4 resources exist and are accessible in Azure Portal
2. **Configuration Injection Test**: Confirm Functions App Application Settings contain correct values
3. **SQL Schema Validation**: Run EF Core migrations and verify tables exist
4. **Call Initiation Test**: POST to `https://{FUNCTIONS_APP_DOMAIN}/api/calls/initiate/{memberId}` (e.g., your Functions App URL from Azure Portal) and verify response

### Post-Deployment Checklist
- [ ] Resource Group `rg-healthcare-call-agent-prod` exists with correct tags
- [ ] Storage Account (e.g., `sthealthcarecaprod`) is accessible and has no errors
- [ ] Functions App (e.g., `func-healthcare-call-agent-prod`) shows "Running" in Azure Portal
- [ ] SQL Server (e.g., `sql-healthcare-call-agent-prod`) is online and accessible
- [ ] SQL Database `HealthcareCallAgentDb` firewall rule allows Azure services
- [ ] Functions App Application Settings show all 5 configuration values
- [ ] No authentication errors in Functions App logs
- [ ] Manual test call succeeds: `POST /api/calls/initiate/1` returns session ID

---

## Edge Cases

- What happens if shared resources (ACS, AI Services) are not found in the shared RG? → IaC deployment should fail with clear error message
- What happens if service principal lacks Reader role on shared RG? → IaC cannot query resources; deployment fails with permission denied error
- What happens if SQL Database firewall rule is not created? → Functions App cannot connect to database; queries timeout
- What happens if Functions App cold start takes > 10 seconds? → Users experience initial latency; acceptable for MVP, monitor for Phase 2 optimization
- What happens if connection string injection fails? → Functions App Application Settings are incomplete; call initiation endpoint returns 500 error

---

## Next Steps

1. ✅ **Review Specification**: Stakeholders review and approve this specification
2. 📋 **Create Planning Document**: Generate actionable tasks and timeline for implementation
3. 🔐 **Configure RBAC**: Set up GitHub Actions service principal with required permissions
4. 📝 **Create IaC Templates**: Develop Bicep templates based on deployment plan
5. 🚀 **Execute Deployment**: Run IaC to provision infrastructure
6. ✔️ **Validate Deployment**: Execute post-deployment checklist
7. 📊 **Monitor Costs**: Track actual spend vs. projections (~$122/month)
8. 🔒 **Plan Security Hardening**: Schedule Phase 2 work for Key Vault and VNet

---

## References

- [Azure Communication Services Documentation](https://learn.microsoft.com/en-us/azure/communication-services/)
- [Azure Functions Documentation](https://learn.microsoft.com/en-us/azure/azure-functions/)
- [Azure SQL Database Documentation](https://learn.microsoft.com/en-us/azure/azure-sql/)
- [Bicep Language Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [GitHub Actions Azure Login](https://github.com/Azure/login)
- [Entity Framework Core Migrations](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/)
- [Cross-Resource Group Deployments Pattern](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/common-deployment-errors)

---

## Compliance Notes

### Azure Key Vault RBAC Compliance (Phase 2)
When Key Vault is implemented in Phase 2, it **MUST** comply with the following requirements:

- **API Version Guidance**: Use a **currently supported/stable Azure Key Vault resource API version** in the Key Vault Bicep module (avoid deprecated or retired API versions, and periodically bump the module’s API version as Azure retires older versions)
- **Access Control Model**: Use Azure RBAC (`enableRbacAuthorization: true`) instead of legacy access policies
- **Retirement Monitoring**: Review official Azure updates for Key Vault API version and feature retirement notices and ensure that all new Key Vault instances use only supported API versions and RBAC-based access control
- **RBAC Roles**: Assign built-in Azure roles (Key Vault Secrets Officer, Key Vault Secrets User) to managed identities using principle of least privilege
- **No Legacy Access Policies**: Phase 2 deployment must not create any legacy access policy entries
- **Bicep Template**: Key Vault module must be updated to enforce RBAC as the default access control model

Referencing:
- Azure Key Vault RBAC guidance: https://learn.microsoft.com/azure/key-vault/general/rbac-guide
- Azure Updates for Key Vault announcements: https://azure.microsoft.com/updates/?category=security&query=Key%20Vault

---

**Document Status**: ✅ **Ready for Planning Phase**

**Created by**: GitHub Copilot  
**Date**: January 31, 2026  
**Version**: 1.0
