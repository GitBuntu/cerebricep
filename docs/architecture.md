# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Azure Subscription                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Resource Group (rg-cerebricep-{env})              │   │
│  │                                                                       │   │
│  │  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐         │   │
│  │  │   Function   │────▶│   Cosmos DB  │     │  Document    │         │   │
│  │  │     App      │     │   (NoSQL)    │     │ Intelligence │         │   │
│  │  └──────────────┘     └──────────────┘     └──────────────┘         │   │
│  │         │                    ▲                    ▲                   │   │
│  │         │                    │                    │                   │   │
│  │         ▼                    │                    │                   │   │
│  │  ┌──────────────┐           │                    │                   │   │
│  │  │   Storage    │───────────┘                    │                   │   │
│  │  │   Account    │────────────────────────────────┘                   │   │
│  │  └──────────────┘                                                     │   │
│  │         │                                                             │   │
│  │         │         ┌──────────────┐     ┌──────────────┐              │   │
│  │         └────────▶│  Key Vault   │     │    App       │              │   │
│  │                   │              │     │ Configuration│              │   │
│  │                   └──────────────┘     │(Feature Flags│              │   │
│  │                          ▲             └──────────────┘              │   │
│  │                          │                    ▲                       │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │              User-Assigned Managed Identity                   │   │   │
│  │  │         (Passwordless auth to all services)                   │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                       │   │
│  │  ┌──────────────┐     ┌──────────────┐                              │   │
│  │  │     App      │────▶│ Log Analytics│                              │   │
│  │  │   Insights   │     │  Workspace   │                              │   │
│  │  └──────────────┘     └──────────────┘                              │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### Compute Layer

**Azure Functions**
- Serverless compute for AI workloads
- Elastic Premium plan for production (faster cold start, VNET integration)
- Consumption plan for development (cost-optimized)

### Data Layer

**Cosmos DB (NoSQL)**
- Global distribution capability
- Automatic indexing
- Session consistency for optimal performance
- Serverless or provisioned throughput based on workload

**Storage Account**
- Blob storage for documents
- Function App backend storage
- Versioning enabled for data protection

### AI Services

**Document Intelligence**
- Prebuilt models for common document types
- Custom model training support
- Form recognition and data extraction

### Configuration & Secrets

**Key Vault**
- Centralized secrets management
- RBAC-based access control
- Soft delete and purge protection

**App Configuration**
- Feature flag management
- Centralized configuration
- Label-based configuration versioning

### Identity & Security

**User-Assigned Managed Identity**
- Single identity used by all services
- No credentials in code or config
- RBAC permissions to all dependent services

### Monitoring

**Application Insights**
- Distributed tracing
- Performance monitoring
- Availability testing

**Log Analytics**
- Centralized log aggregation
- KQL query support
- Alert integration

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Runner                        │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │            OIDC Token Exchange                           │    │
│  │      (No secrets stored in GitHub)                       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                    │
└──────────────────────────────┼────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Azure AD                                   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │         Workload Identity Federation                     │    │
│  │    (App Registration + Federated Credentials)            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                    │
└──────────────────────────────┼────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Azure Resources                               │
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Managed ID  │──│  Key Vault  │  │    All Services         │  │
│  │   (RBAC)    │  │  (Secrets)  │  │  (Passwordless Auth)    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Flow

```
Developer Push          PR Validation              Deployment
     │                       │                          │
     ▼                       ▼                          ▼
┌─────────┐            ┌──────────┐              ┌──────────┐
│  main   │───────────▶│  Lint    │              │   Dev    │
│ branch  │            │  What-If │              │  (auto)  │
└─────────┘            │  Checkov │              └──────────┘
                       └──────────┘                    │
                             │                         │
                             ▼                         ▼
                       ┌──────────┐              ┌──────────┐
                       │  Merge   │─────────────▶│   UAT    │
                       │   PR     │              │ (manual) │
                       └──────────┘              └──────────┘
                                                       │
                                                       ▼
                                                 ┌──────────┐
                                                 │   Prod   │
                                                 │(approval)│
                                                 └──────────┘
```
