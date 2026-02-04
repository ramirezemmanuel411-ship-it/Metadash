#!/bin/bash

# FatSecret OAuth Proxy - Verification Script
# Test that proxy is working correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if URL provided
if [ -z "$1" ]; then
  URL="http://localhost:8080"
  echo -e "${YELLOW}No URL provided, testing local: $URL${NC}\n"
else
  URL="$1"
  echo -e "${YELLOW}Testing: $URL${NC}\n"
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  FatSecret OAuth Proxy Verification       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}\n"

# Test 1: Health check
echo -e "${YELLOW}[TEST 1]${NC} Health Check"
echo "  GET $URL/health"
if response=$(curl -s -w "\n%{http_code}" "$URL/health" 2>/dev/null); then
  http_code=$(echo "$response" | tail -n 1)
  body=$(echo "$response" | head -n -1)
  
  if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Status: $http_code${NC}"
    echo -e "  Response: $body"
  else
    echo -e "${RED}❌ Status: $http_code${NC}"
    echo -e "  Response: $body"
  fi
else
  echo -e "${RED}❌ Could not connect to $URL${NC}"
  exit 1
fi
echo ""

# Test 2: Token endpoint
echo -e "${YELLOW}[TEST 2]${NC} Token Endpoint"
echo "  GET $URL/token"
if response=$(curl -s -w "\n%{http_code}" "$URL/token" 2>/dev/null); then
  http_code=$(echo "$response" | tail -n 1)
  body=$(echo "$response" | head -n -1)
  
  if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Status: $http_code${NC}"
    # Extract expires_in safely
    expires_in=$(echo "$body" | grep -o '"expires_in":[0-9]*' | head -1 | cut -d':' -f2)
    echo -e "  Token expires in: $expires_in seconds"
  else
    echo -e "${RED}❌ Status: $http_code${NC}"
  fi
else
  echo -e "${RED}❌ Could not connect to $URL/token${NC}"
fi
echo ""

# Test 3: Proxy request (search)
echo -e "${YELLOW}[TEST 3]${NC} FatSecret Request (Search Foods)"
echo "  GET $URL/food.search.v3.1?search_expression=coke"
if response=$(curl -s -w "\n%{http_code}" "$URL/food.search.v3.1?search_expression=coke" 2>/dev/null); then
  http_code=$(echo "$response" | tail -n 1)
  body=$(echo "$response" | head -n -1)
  
  case $http_code in
    200)
      echo -e "${GREEN}✅ Status: $http_code${NC}"
      # Count foods in response
      food_count=$(echo "$body" | grep -o '"food_id"' | wc -l)
      echo -e "  Found foods in response: $food_count"
      ;;
    403)
      echo -e "${RED}❌ Status: $http_code (Likely IP not whitelisted)${NC}"
      echo -e "  ${YELLOW}Action: Whitelist your IP on FatSecret dashboard${NC}"
      ;;
    401)
      echo -e "${RED}❌ Status: $http_code (Unauthorized - token issue)${NC}"
      echo -e "  ${YELLOW}Action: Check CLIENT_ID and CLIENT_SECRET${NC}"
      ;;
    *)
      echo -e "${YELLOW}⚠️  Status: $http_code${NC}"
      echo -e "  Response: ${body:0:100}..."
      ;;
  esac
else
  echo -e "${RED}❌ Could not connect to $URL/food.search.v3.1${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Verification Summary                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}Next steps:${NC}"
echo "  1. If health check ✅ → Proxy is running"
echo "  2. If search returns ✅ → FatSecret integration works"
echo "  3. If IP restricted ❌ → Whitelist your IP"
echo "  4. If tokens fail ❌ → Check credentials"
echo ""
echo -e "${YELLOW}For debugging:${NC}"
echo "  • Check logs: railway/heroku/digitalocean dashboard"
echo "  • Test manually: curl $URL/health"
echo "  • Monitor: Check incoming requests to verify traffic"
