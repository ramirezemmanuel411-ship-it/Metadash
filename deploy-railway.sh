#!/bin/bash

# FatSecret OAuth Proxy - Railway Deployment Script
# This script automates the deployment to Railway
# 
# Prerequisites:
# 1. Railway CLI installed: npm install -g @railway/cli
# 2. GitHub account with metadash repository
# 3. Railway account: https://railway.app
#
# Usage: bash deploy-railway.sh

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║        FatSecret OAuth Proxy - Railway Deployment              ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo -e "${YELLOW}Railway CLI not found. Installing...${NC}"
    npm install -g @railway/cli
fi

# Check if git is initialized
if [ ! -d .git ]; then
    echo -e "${YELLOW}Git not initialized. Initializing repository...${NC}"
    git init
    git add .
    git commit -m "Initial commit: FatSecret OAuth Proxy"
fi

# Step 1: Login to Railway
echo ""
echo -e "${BLUE}Step 1: Logging in to Railway...${NC}"
railway login

# Step 2: Create new Railway project
echo ""
echo -e "${BLUE}Step 2: Creating new Railway project...${NC}"
railway init

# Step 3: Set root directory to deployment/
echo ""
echo -e "${BLUE}Step 3: Configuring deployment directory...${NC}"
railway variables set ROOT_DIR=deployment

# Step 4: Set environment variables
echo ""
echo -e "${BLUE}Step 4: Setting FatSecret credentials...${NC}"
railway variables set FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0
railway variables set FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
railway variables set PORT=8080

# Step 5: Deploy
echo ""
echo -e "${BLUE}Step 5: Deploying to Railway...${NC}"
railway up

# Step 6: Get deployment URL
echo ""
echo -e "${GREEN}Deployment Complete!${NC}"
echo ""
echo -e "${BLUE}Getting deployment information...${NC}"
RAILWAY_URL=$(railway env | grep RAILWAY_PUBLIC_DOMAIN | cut -d'=' -f2)
STATIC_IP=$(railway env | grep RAILWAY_STATIC_IP | cut -d'=' -f2)

echo ""
echo -e "${GREEN}✅ Deployment Successful!${NC}"
echo ""
echo -e "${BLUE}Your Backend Proxy URL:${NC}"
echo "https://$RAILWAY_URL"
echo ""
echo -e "${BLUE}Your Static IP (for FatSecret whitelist):${NC}"
echo "$STATIC_IP"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Go to: https://platform.fatsecret.com/my-account/ip-restrictions"
echo "2. Add IP: $STATIC_IP/32"
echo "3. Wait for FatSecret to activate (0-24 hours)"
echo "4. Update mobile app with backend URL: https://$RAILWAY_URL"
echo "5. Test in mobile app"
echo ""
