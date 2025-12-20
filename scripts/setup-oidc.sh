#!/bin/bash

# Complete OIDC Setup for GitHub Actions Deployment to Azure
# Handles: App registration → Service principal → Role assignment → Federated credential
# Usage: ./setup-oidc.sh <GITHUB_USERNAME> <SUBSCRIPTION_ID> [GITHUB_REPO] [APP_NAME]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Input validation
if [ $# -lt 2 ]; then
    echo -e "${RED}Usage: $0 <GITHUB_USERNAME> <SUBSCRIPTION_ID> [GITHUB_REPO] [APP_NAME]${NC}"
    echo ""
    echo "Example:"
    echo "  $0 GitBuntu a441c5ec-890a-4781-8cf8-a29210a2278e cerebricep github-authpilot-deployer"
    echo ""
    echo "Defaults:"
    echo "  GITHUB_REPO: cerebricep"
    echo "  APP_NAME: github-authpilot-deployer"
    exit 1
fi

GITHUB_USERNAME=$1
SUBSCRIPTION_ID=$2
GITHUB_REPO=${3:-cerebricep}
APP_NAME=${4:-github-authpilot-deployer}

echo -e "${YELLOW}=== Complete OIDC Setup for GitHub Actions ===${NC}"
echo "GitHub Username: $GITHUB_USERNAME"
echo "GitHub Repo: $GITHUB_REPO"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "App Name: $APP_NAME"
echo ""

# Verify Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found. Install it first.${NC}"
    exit 1
fi

# Verify authenticated
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not authenticated. Run 'az login' first.${NC}"
    exit 1
fi

# ============================================================================
# STEP 1: Create or retrieve Azure AD app registration
# ============================================================================
echo -e "${YELLOW}Step 1: Checking Azure AD app registration...${NC}"

# Check if app already exists by display name
EXISTING_APP=$(az ad app list --display-name $APP_NAME --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -z "$EXISTING_APP" ]; then
    echo "   Creating new app registration: $APP_NAME"
    APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)
    echo -e "${GREEN}✅ App created: $APP_ID${NC}"
else
    APP_ID=$EXISTING_APP
    echo -e "${YELLOW}⚠️  App already exists: $APP_ID${NC}"
fi

echo ""

# ============================================================================
# STEP 2: Create or retrieve service principal
# ============================================================================
echo -e "${YELLOW}Step 2: Checking service principal...${NC}"

# Check if service principal exists
EXISTING_SP=$(az ad sp list --display-name $APP_NAME --query "[0].id" -o tsv 2>/dev/null || echo "")

if [ -z "$EXISTING_SP" ]; then
    echo "   Creating new service principal for: $APP_ID"
    SP_OBJECT_ID=$(az ad sp create --id $APP_ID --query id -o tsv)
    echo -e "${GREEN}✅ Service principal created: $SP_OBJECT_ID${NC}"
else
    SP_OBJECT_ID=$EXISTING_SP
    echo -e "${YELLOW}⚠️  Service principal already exists: $SP_OBJECT_ID${NC}"
fi

echo ""

# ============================================================================
# STEP 3: Set subscription context and get tenant ID
# ============================================================================
echo -e "${YELLOW}Step 3: Setting subscription context...${NC}"

az account set --subscription $SUBSCRIPTION_ID
TENANT_ID=$(az account show --query tenantId -o tsv)

echo -e "${GREEN}✅ Subscription context set${NC}"
echo "   Tenant ID: $TENANT_ID"
echo ""

# ============================================================================
# STEP 4: Assign User Access Administrator role to service principal
# ============================================================================
echo -e "${YELLOW}Step 4: Assigning User Access Administrator role...${NC}"

# Check if role already assigned
ROLE_EXISTS=$(az role assignment list \
  --assignee $SP_OBJECT_ID \
  --role "User Access Administrator" \
  --scope /subscriptions/$SUBSCRIPTION_ID \
  --query "[0].id" -o tsv 2>/dev/null || echo "")

if [ -z "$ROLE_EXISTS" ]; then
    az role assignment create \
      --role "User Access Administrator" \
      --assignee-object-id $SP_OBJECT_ID \
      --assignee-principal-type ServicePrincipal \
      --scope /subscriptions/$SUBSCRIPTION_ID
    echo -e "${GREEN}✅ User Access Administrator role assigned${NC}"
else
    echo -e "${YELLOW}⚠️  Role already assigned${NC}"
fi

echo ""

# ============================================================================
# STEP 5: Create federated identity credential
# ============================================================================
echo -e "${YELLOW}Step 5: Creating federated identity credential...${NC}"

# Check if federated credential already exists
FEDERATED_EXISTS=$(az ad app federated-credential list --id $APP_ID --query "[?name=='github-authpilot'].id" -o tsv 2>/dev/null || echo "")

if [ -z "$FEDERATED_EXISTS" ]; then
    az ad app federated-credential create \
      --id $APP_ID \
      --parameters '{
        "name": "github-authpilot",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:'"${GITHUB_USERNAME}"'/'"${GITHUB_REPO}"':ref:refs/heads/dev",
        "description": "GitHub Actions OIDC for AuthPilot dev deployment",
        "audiences": ["api://AzureADTokenExchange"]
      }' > /dev/null
    echo -e "${GREEN}✅ Federated credential created${NC}"
else
    echo -e "${YELLOW}⚠️  Federated credential already exists${NC}"
fi

echo ""

# ============================================================================
# STEP 6: Output GitHub secrets configuration
# ============================================================================
echo -e "${GREEN}=== GitHub Repository Secrets Configuration ===${NC}"
echo ""
echo "Go to: GitHub repo → Settings → Secrets and variables → Actions"
echo "Click: New repository secret (add each one separately)"
echo ""
echo -e "${YELLOW}Secret 1: AZURE_CLIENT_ID${NC}"
echo "   Value: ${APP_ID}"
echo ""
echo -e "${YELLOW}Secret 2: AZURE_TENANT_ID${NC}"
echo "   Value: ${TENANT_ID}"
echo ""
echo -e "${YELLOW}Secret 3: AZURE_SUBSCRIPTION_ID${NC}"
echo "   Value: ${SUBSCRIPTION_ID}"
echo ""
echo -e "${YELLOW}Secret 4: AZURE_REGION${NC}"
echo "   Value: eastus"
echo ""

# ============================================================================
# STEP 7: Output next steps
# ============================================================================
echo -e "${GREEN}=== Next Steps ===${NC}"
echo ""
echo "1. Add the 4 secrets above to your GitHub repository"
echo ""
echo "2. Create the resource group (if not already created):"
echo "   ./scripts/create-resource-group.sh rg-authpilot-dev eastus"
echo ""
echo "3. Push to dev branch to trigger deployment:"
echo "   git add ."
echo "   git commit -m 'Enable OIDC and infrastructure deployment'"
echo "   git push origin dev"
echo ""
echo "4. Monitor deployment in GitHub Actions → Deploy AuthPilot Infrastructure"
echo ""
echo -e "${GREEN}✅ OIDC setup complete!${NC}"
