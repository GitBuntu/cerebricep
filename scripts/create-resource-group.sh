#!/bin/bash

# Create Azure Resource Group for AuthPilot Deployment
# Usage: ./create-resource-group.sh [RESOURCE_GROUP_NAME] [REGION]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Defaults
RESOURCE_GROUP_NAME=${1:-rg-authpilot-dev}
REGION=${2:-eastus2}

echo -e "${YELLOW}=== Creating Azure Resource Group ===${NC}"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Region: $REGION"
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

# Check if resource group already exists
if az group exists --name $RESOURCE_GROUP_NAME | grep -q true; then
    echo -e "${YELLOW}⚠️  Resource group '$RESOURCE_GROUP_NAME' already exists${NC}"
    exit 0
fi

echo -e "${YELLOW}Creating resource group...${NC}"
az group create \
  --name $RESOURCE_GROUP_NAME \
  --location $REGION

echo ""
echo -e "${GREEN}✅ Resource group created successfully${NC}"
echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Add GitHub Secrets (if not done already):"
echo "   Go to GitHub repo → Settings → Secrets and variables → Actions"
echo "   Add: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, AZURE_REGION"
echo ""
echo "2. Push to dev branch to trigger GitHub Actions deployment:"
echo "   git add ."
echo "   git commit -m 'Enable OIDC and infrastructure deployment'"
echo "   git push origin dev"
echo ""
echo "3. Monitor deployment in GitHub Actions tab"
