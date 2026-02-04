#!/bin/bash

# FatSecret OAuth Proxy - Deployment Helper Script
# Usage: bash deploy.sh [platform]
# Platforms: railway, heroku, digitalocean, local

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}FatSecret OAuth Proxy - Deployment Helper${NC}\n"

# Get platform
PLATFORM=${1:-"railway"}

case $PLATFORM in
  "local")
    echo -e "${YELLOW}[1/3]${NC} Checking prerequisites..."
    
    if ! command -v dart &> /dev/null; then
      echo -e "${RED}❌ Dart not found. Install from https://dart.dev${NC}"
      exit 1
    fi
    echo -e "${GREEN}✅ Dart installed${NC}"
    
    if ! command -v git &> /dev/null; then
      echo -e "${RED}❌ Git not found. Install from https://git-scm.com${NC}"
      exit 1
    fi
    echo -e "${GREEN}✅ Git installed${NC}"
    
    echo -e "\n${YELLOW}[2/3]${NC} Getting dependencies..."
    dart pub get
    
    echo -e "\n${YELLOW}[3/3]${NC} Running locally..."
    echo -e "${YELLOW}💡 Make sure environment variables are set:${NC}"
    echo "  export FATSECRET_CLIENT_ID=..."
    echo "  export FATSECRET_CLIENT_SECRET=..."
    echo ""
    
    dart run \
      --define FATSECRET_CLIENT_ID="${FATSECRET_CLIENT_ID:-b9f7e7de97b340b7915c3ac9bab9bfe0}" \
      --define FATSECRET_CLIENT_SECRET="${FATSECRET_CLIENT_SECRET:-b788a80bfaaf4e569e811a381be3865f}"
    ;;
    
  "railway")
    echo -e "${GREEN}Railway Deployment Guide${NC}"
    echo ""
    echo -e "1. Create GitHub repo:"
    echo "   git init && git add . && git commit -m 'Initial commit'"
    echo "   git remote add origin https://github.com/YOUR/fatsecret-proxy.git"
    echo "   git push -u origin main"
    echo ""
    echo -e "2. Go to https://railway.app"
    echo "   Click 'Login with GitHub' → 'Create New Project'"
    echo "   Select 'Deploy from GitHub repo' → 'fatsecret-proxy'"
    echo ""
    echo -e "3. Set environment variables in Railway:"
    echo "   FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0"
    echo "   FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f"
    echo ""
    echo -e "4. Railway auto-deploys (watch logs)"
    echo ""
    echo -e "${YELLOW}📖 For detailed guide: see DEPLOY_RAILWAY.md${NC}"
    ;;
    
  "heroku")
    echo -e "${GREEN}Heroku Deployment Guide${NC}"
    echo ""
    echo "Prerequisites:"
    echo "  brew install heroku/brew/heroku  # macOS"
    echo "  heroku login"
    echo ""
    echo "Deployment:"
    echo "  heroku create your-app-name"
    echo "  heroku config:set FATSECRET_CLIENT_ID=..."
    echo "  heroku config:set FATSECRET_CLIENT_SECRET=..."
    echo "  git push heroku main"
    echo ""
    echo -e "${YELLOW}Monitor logs:${NC}"
    echo "  heroku logs --tail"
    echo ""
    echo -e "${YELLOW}Note: Requires Procfile${NC}"
    ;;
    
  "digitalocean")
    echo -e "${GREEN}DigitalOcean Deployment Guide${NC}"
    echo ""
    echo "Prerequisites:"
    echo "  1. Create DigitalOcean account"
    echo "  2. Create App Platform"
    echo "  3. Connect GitHub repo"
    echo ""
    echo "Environment Variables:"
    echo "  FATSECRET_CLIENT_ID"
    echo "  FATSECRET_CLIENT_SECRET"
    echo ""
    echo "Build Command: dart pub get"
    echo "Run Command: dart bin/main.dart"
    echo ""
    echo -e "${YELLOW}Estimated cost: $5-12/month${NC}"
    ;;
    
  *)
    echo -e "${RED}Unknown platform: $PLATFORM${NC}"
    echo ""
    echo "Usage: bash deploy.sh [platform]"
    echo "Platforms: local, railway, heroku, digitalocean"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}✅ Deployment guide shown${NC}"
