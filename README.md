# Cerebricep - AI Workloads on Azure

Infrastructure as Code (IaC) for deploying AI workloads to Azure using Bicep and GitHub Actions.

## 🏗️ Architecture

This project deploys the following Azure resources:

| Resource | Purpose |
|----------|---------|
| **Azure Functions** | Serverless compute for AI workloads |
| **Document Intelligence** | Document processing and extraction |
| **Cosmos DB** | NoSQL database for application data |
| **App Configuration** | Feature flags and configuration management |
| **Key Vault** | Secrets management |
| **Storage Account** | Blob storage for documents and data |
| **Application Insights** | Monitoring and telemetry |
| **Log Analytics** | Centralized logging |
| **User-Assigned Managed Identity** | Secure, passwordless authentication |

## 📁 Project Structure

```
cerebricep/
├── .github/
│   ├── workflows/
│   │   ├── infra-deploy.yml      # Deployment workflow
│   │   └── infra-validate.yml    # PR validation workflow
│   └── CODEOWNERS
│
├── infra/
│   ├── main.bicep                # Main orchestration template
│   ├── modules/
│   │   ├── ai/                   # AI services (Document Intelligence, etc.)
│   │   ├── compute/              # Function Apps, App Service Plans
│   │   ├── config/               # Key Vault, App Configuration
│   │   ├── data/                 # Cosmos DB, Storage
│   │   ├── identity/             # Managed Identities
│   │   └── monitoring/           # App Insights, Log Analytics
│   └── environments/
│       ├── dev.bicepparam        # Development parameters
│       ├── uat.bicepparam        # UAT parameters
│       └── prod.bicepparam       # Production parameters
│
├── bicepconfig.json              # Bicep linting rules
└── README.md
```

## 🚀 Deployment

### Prerequisites

1. **Azure Subscription** with appropriate permissions
2. **GitHub Repository** with Actions enabled
3. **Azure AD App Registration** configured for OIDC authentication

### Setting Up OIDC Authentication

1. Create an Azure AD App Registration
2. Configure Federated Credentials for GitHub Actions
3. Assign appropriate RBAC roles (Contributor at subscription level)

### GitHub Environment Configuration

Create three environments in GitHub: `dev`, `uat`, `prod`

For each environment, configure these variables:

| Variable | Description |
|----------|-------------|
| `AZURE_CLIENT_ID` | App Registration Client ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure Subscription |
| `AZURE_REGION` | Deployment region (e.g., `eastus2`) |

### Deployment Methods

#### Automatic (Push to Main)
Pushing to `main` automatically deploys to the **dev** environment.

#### Manual (Workflow Dispatch)
1. Go to **Actions** → **Deploy Infrastructure**
2. Click **Run workflow**
3. Select the target environment
4. Click **Run workflow**

## 🔒 Security

- **No stored secrets** - Uses OIDC/Workload Identity Federation
- **Managed Identities** - All services use managed identity for authentication
- **Key Vault** - Application secrets stored in Key Vault
- **RBAC** - Role-based access control throughout
- **Private Endpoints** - Available for UAT/Prod (configurable)

## 🏷️ Environment Differences

| Feature | Dev | UAT | Prod |
|---------|-----|-----|------|
| Function App SKU | Y1 (Consumption) | EP1 (Premium) | EP2 (Premium) |
| Cosmos DB RU/s | 400 | 1,000 | 4,000 |
| Document Intelligence | F0 (Free) | S0 (Standard) | S0 (Standard) |
| Private Endpoints | ❌ | ✅ | ✅ |
| Zone Redundancy | ❌ | ❌ | ✅ |

## 📊 Monitoring

All resources are connected to Application Insights and Log Analytics for:
- Performance monitoring
- Error tracking
- Custom telemetry
- Log aggregation

## 🧪 Validation

Pull requests automatically trigger:
- **Bicep Linting** - Syntax and best practice checks
- **What-If Analysis** - Preview of changes
- **Security Scan** - Checkov security analysis

## 📚 Documentation

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)

## 🤝 Contributing

1. Create a feature branch
2. Make changes
3. Open a PR (validation runs automatically)
4. Get approval from CODEOWNERS
5. Merge to main (deploys to dev automatically)

## 📄 License

See [LICENSE](LICENSE) for details.
