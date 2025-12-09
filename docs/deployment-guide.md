# Deployment Guide

This guide walks through setting up the infrastructure deployment pipeline.

## Prerequisites

- Azure Subscription with Owner or Contributor + User Access Administrator roles
- GitHub repository with Actions enabled
- Azure CLI installed locally (for initial setup)

## Step 1: Create Azure AD App Registration

```bash
# Login to Azure
az login

# Create App Registration
az ad app create --display-name "cerebricep-github-actions"

# Note the appId (client ID) from the output
```

## Step 2: Create Service Principal

```bash
# Create service principal (replace <app-id> with your App Registration ID)
az ad sp create --id <app-id>

# Get the Object ID of the service principal
az ad sp show --id <app-id> --query id -o tsv
```

## Step 3: Configure Federated Credentials

Create federated credentials for each environment:

### For Main Branch (Dev)

```bash
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:GitBuntu/cerebricep:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### For Environment: Dev

```bash
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "github-env-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:GitBuntu/cerebricep:environment:dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### For Environment: UAT

```bash
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "github-env-uat",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:GitBuntu/cerebricep:environment:uat",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### For Environment: Prod

```bash
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "github-env-prod",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:GitBuntu/cerebricep:environment:prod",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### For Pull Requests

```bash
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "github-pull-request",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:GitBuntu/cerebricep:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

## Step 4: Assign Azure RBAC Roles

```bash
# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get the service principal Object ID
SP_OBJECT_ID=$(az ad sp show --id <app-id> --query id -o tsv)

# Assign Contributor role at subscription level
az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Assign User Access Administrator for RBAC assignments
az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

## Step 5: Configure GitHub Environments

### Create Environments

1. Go to **Settings** → **Environments**
2. Create three environments: `dev`, `uat`, `prod`

### Configure Environment Variables

For each environment, add these variables:

| Variable | Value |
|----------|-------|
| `AZURE_CLIENT_ID` | Your App Registration Client ID |
| `AZURE_TENANT_ID` | Your Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your Azure Subscription ID |
| `AZURE_REGION` | `eastus2` (or your preferred region) |

### Configure Protection Rules (Recommended)

**Dev Environment:**
- No protection rules (auto-deploy)

**UAT Environment:**
- Required reviewers: Optional
- Wait timer: 0 minutes

**Prod Environment:**
- Required reviewers: Add approvers
- Wait timer: Consider adding a delay

## Step 6: Test the Deployment

### Trigger Dev Deployment

Push a change to the `infra/` directory on the `main` branch, or manually trigger the workflow:

1. Go to **Actions** → **Deploy Infrastructure**
2. Click **Run workflow**
3. Select `dev` environment
4. Click **Run workflow**

### Monitor the Deployment

1. Watch the workflow progress in the Actions tab
2. Check Azure portal for the created resources
3. Review deployment outputs

## Troubleshooting

### Common Issues

**Error: AADSTS70021 - No matching federated identity record found**
- Verify federated credential subjects match exactly
- Check repository name and environment name

**Error: Authorization failed**
- Verify RBAC role assignments
- Ensure service principal has sufficient permissions

**Error: Subscription not found**
- Verify `AZURE_SUBSCRIPTION_ID` is correct
- Ensure service principal has access to the subscription

### Validate Locally

```bash
# Build Bicep template locally
az bicep build --file infra/main.bicep

# Run what-if deployment
az deployment sub what-if \
  --location eastus2 \
  --template-file infra/main.bicep \
  --parameters infra/environments/dev.bicepparam
```

## Post-Deployment

After successful deployment:

1. **Verify Resources** - Check Azure portal for all expected resources
2. **Test Connectivity** - Verify Function App can access dependent services
3. **Configure Alerts** - Set up monitoring alerts in Application Insights
4. **Add Application Secrets** - Populate Key Vault with any required secrets

## Cleanup

To destroy all resources:

```bash
# Delete resource group (this deletes all resources within)
az group delete --name rg-cerebricep-dev --yes --no-wait
az group delete --name rg-cerebricep-uat --yes --no-wait
az group delete --name rg-cerebricep-prod --yes --no-wait
```
