# Cerebricep - Azure Infrastructure as Code

Infrastructure as Code (IaC) project for deploying workloads to Azure using Bicep and GitHub Actions with a workload-centric architecture.

## 🏗️ Architecture

**Workload-Centric Design**: Each workload is completely self-contained with its own deployment template, parameters, and pipeline. Workloads are independent and compose shared modules as needed.

### Current Workloads

#### AuthPilot
Fax processing pipeline with Azure DocumentDB (MongoDB).

**Resources:**
- Azure DocumentDB (MongoDB-compatible cluster)
- Resource Group (isolated per environment)

**Environments:**
- **dev**: M10 tier, 32GB storage
- **uat**: M30 tier, 64GB storage (if configured)
- **prod**: M50 tier, 256GB storage, high availability (if configured)

### Available Shared Modules

Reusable building blocks that workloads can compose:

| Module | Purpose |
|--------|---------|
| `ai/document-intelligence` | Document processing and extraction |
| `compute/function-app` | Serverless Azure Functions (Y1/EP1/EP2/Flex) |
| `config/app-configuration` | Feature flags and configuration |
| `config/key-vault` | Secrets management with RBAC |
| `data/cosmos-db` | Cosmos DB with MongoDB API |
| `data/documentdb` | Azure DocumentDB (MongoDB cluster) |
| `data/storage-account` | Blob storage with versioning |
| `identity/user-assigned-identity` | Managed identity for passwordless auth |
| `monitoring/log-analytics` | Application Insights + Log Analytics |

## 📁 Project Structure

```
cerebricep/
├── .github/
│   ├── workflows/
│   │   ├── deploy-authpilot.yml  # AuthPilot deployment
│   │   └── validate.yml          # PR validation
│   └── copilot-instructions.md   # Development guidelines
│
├── infra/
│   ├── modules/                  # Shared building blocks
│   │   ├── ai/                   # Document Intelligence
│   │   ├── compute/              # Function Apps
│   │   ├── config/               # Key Vault, App Configuration
│   │   ├── data/                 # Cosmos DB, DocumentDB, Storage
│   │   ├── identity/             # Managed Identities
│   │   └── monitoring/           # App Insights, Log Analytics
│   │
│   └── workloads/
│       └── authpilot/            # AuthPilot workload (self-contained)
│           ├── main.bicep        # Subscription-scope orchestration
│           └── environments/
│               ├── dev.bicepparam
│               ├── uat.bicepparam (optional)
│               └── prod.bicepparam (optional)
│
├── docs/
│   ├── architecture.md
│   ├── deployment-guide.md
│   └── OIDC-SETUP-GUIDE.md
│
├── bicepconfig.json              # Bicep linting rules
└── README.md
```

## 🚀 Deployment

### Prerequisites

1. **Azure Subscription** with appropriate permissions
2. **GitHub Repository** with Actions enabled
3. **Azure AD App Registration** configured for OIDC authentication (see [OIDC Setup Guide](docs/OIDC-SETUP-GUIDE.md))

### GitHub Environment Configuration

For each workload environment (e.g., `dev`), configure these secrets:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | App Registration Client ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure Subscription |
| `DOCUMENTDB_ADMIN_PASSWORD` | DocumentDB admin password (for authpilot) |

### Deploying AuthPilot

#### Via GitHub Actions (Recommended)
1. Push to `dev` branch - automatically deploys to dev environment
2. **OR** Go to **Actions** → **Deploy AuthPilot Infrastructure** → **Run workflow**

#### Via Azure CLI (Manual)
```bash
az deployment sub create \
  --location eastus \
  --template-file infra/workloads/authpilot/main.bicep \
  --parameters infra/workloads/authpilot/environments/dev.bicepparam
```

### Adding a New Workload

1. Create directory: `infra/workloads/{workload-name}/`
2. Create `main.bicep` (subscription scope, creates resource group, composes modules)
3. Create `environments/dev.bicepparam`
4. Reference shared modules: `../../modules/{category}/{module}.bicep`
5. Create workflow: `.github/workflows/deploy-{workload-name}.yml`
6. Validate: `az bicep build --file infra/workloads/{workload-name}/main.bicep`
vailable modules support managed identity authentication
- **Key Vault** - Available for application secrets storage
- **RBAC** - Role-based access control in all modules
- **Workload Isolation** - Each workload deploys to its own resource group
- **Key Vault** - Application secrets stored in Key Vault
- **RBAC** - Role-based access control throughout
- *🧪 Validation

Pull requests automatically trigger:
- **Bicep Linting** - Syntax and best practice checks via `bicepconfig.json`
- **Template Validation** - Ensures all workload templates build successfully

### Local Validation
```bash
# Validate a workload
az bicep build --file infra/workloads/authpilot/main.bicep --stdout > /dev/null

# Validate parameter file
az bicep build-params --file infra/workloads/authpilot/environments/dev.bicepparam --outfile /dev/null
```
- **Release Branches** - Higher approval requirements for production-bound code

See [.github/rulesets/README.md](.github/rulesets/README.md) for detailed ruleset documentation.

## 📚 Documentation

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)

## 📄 License

See [LICENSE](LICENSE) for details.
- [OIDC Setup Guide](docs/OIDC-SETUP-GUIDE.md)
- [Copilot Instructions](.github/copilot-instructions.md)

## 🏗️ Design Principles

- **Workload Independence** - Each workload is self-contained with zero cross-dependencies
- **Single Source of Truth** - Workload's `main.bicep` + `environments/*.bicepparam` define everything
- **Module Reusability** - Shared modules are composable building blocks
- **No Scripts** - Everything declared in Bicep (repeatable, version-controlled)
- **Environment Parameterization** - Same template, different parameter files for dev/uat/prod