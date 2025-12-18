# GitHub Actions OIDC Setup - Simple Guide

## What is OIDC?
OIDC (OpenID Connect) allows GitHub Actions to authenticate to Azure **without storing credentials**. GitHub provides a temporary token, Azure verifies it, and grants access. No secrets = safer.

## Prerequisites
- Azure CLI installed (`az login` working)
- GitHub account with repo access
- Owner/admin access to your Azure subscription

---

## Step 1: Get Your Azure Subscription ID

```bash
az account list --output table
```

Copy your **Subscription ID** (looks like: `12345678-1234-1234-1234-123456789012`)

---

## Step 2: Create Azure AD App Registration & Service Principal

**Run this command** (replace `{SUBSCRIPTION_ID}` with your actual ID):

```bash
SUBSCRIPTION_ID="{SUBSCRIPTION_ID}"
APP_NAME="github-authpilot-deployer"

# Create app registration
APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)
echo "App ID: $APP_ID"

# Create service principal
SP_OBJECT_ID=$(az ad sp create --id $APP_ID --query id -o tsv)
echo "Service Principal ID: $SP_OBJECT_ID"

# Grant Contributor role on subscription
az role assignment create --role Contributor --assignee-object-id $SP_OBJECT_ID --scope /subscriptions/$SUBSCRIPTION_ID
echo "✅ Contributor role assigned"
```

**Save these values:**
- `APP_ID` (Azure Client ID)
- `SUBSCRIPTION_ID`

---

## Step 3: Get Your Azure Tenant ID

```bash
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"
```

**Save this value:**
- `TENANT_ID`

---

## Step 4: Create Federated Identity Credential

This tells Azure: "Trust tokens from GitHub Actions for this repo"

**Run this command** (replace values):

```bash
GITHUB_USERNAME="your-github-username"  # YOUR USERNAME (e.g., "chris", "john123", etc.)
GITHUB_REPO="cerebricep"                # repo name
TENANT_ID="{TENANT_ID}"                 # from Step 3
APP_ID="{APP_ID}"                       # from Step 2

az ad app federated-credential create \
  --id $APP_ID \
  --parameters \
  '{
    "name": "github-authpilot",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${GITHUB_USERNAME}"'/'"${GITHUB_REPO}"':ref:refs/heads/dev",
    "description": "GitHub Actions OIDC for AuthPilot dev deployment",
    "audiences": ["api://AzureADTokenExchange"]
  }'

echo "✅ Federated credential created"
```

**Example for personal account:**
If your GitHub username is `chris-dev`, the command would be:
```bash
GITHUB_USERNAME="chris-dev"
```

---

## Step 5: Add GitHub Repository Secrets

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add **4 secrets**:

| Secret Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | (your App ID from Step 2) |
| `AZURE_TENANT_ID` | (your Tenant ID from Step 3) |
| `AZURE_SUBSCRIPTION_ID` | (your Subscription ID from Step 1) |
| `AZURE_REGION` | `eastus2` |

**To get your values:** Run `./scripts/setup-oidc.sh` and copy the values from its output.

---

## Step 6: Create GitHub Environment (Optional but Recommended)

Go to your GitHub repo → **Settings** → **Environments** → **New environment**

Name it: `development`

(This creates a named environment that the workflow can reference)

---

## Step 7: Test It!

Push a change to the `dev` branch:

```bash
git add .
git commit -m "Enable OIDC GitHub Actions deployment"
git push origin dev
```

Go to GitHub repo → **Actions** → Watch the `Deploy AuthPilot Infrastructure` workflow run.

**If it succeeds**: ✅ OIDC is working!
**If it fails**: Check the error message in the workflow logs.

---

## Troubleshooting

### "Federated token validation failure"
- Check that `GITHUB_USERNAME` matches your actual GitHub username exactly
- Check that branch is exactly `dev` (not `main` or `develop`)
- Wait 2-3 minutes after creating federated credential for propagation

### "Resource not found"
- Verify `AZURE_SUBSCRIPTION_ID` is correct
- Verify you have Contributor role: `az role assignment list --assignee $APP_ID`

### "Not authorized to perform action"
- Run: `az role assignment create --role Contributor --assignee-object-id $SP_OBJECT_ID --scope /subscriptions/$SUBSCRIPTION_ID`

---

## What's Next?

After OIDC is working:
1. Create the resource group: `az group create --name rg-authpilot-dev-eastus-001 --location eastus2`
2. Push to dev branch → GitHub Actions deploys infrastructure
3. Check Azure Portal for created resources

---

## Reference: What Each Value Is

| Value | What It Is |
|---|---|
| `AZURE_CLIENT_ID` | App Registration ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |
| `AZURE_REGION` | Deployment region (`eastus2`) |

These allow GitHub Actions to:
1. Get a temporary token from GitHub
2. Exchange it with Azure AD (using Client ID + Tenant ID)
3. Deploy to your Subscription in your Region

---

**That's it!** No credentials stored, no security risk. 🎉
