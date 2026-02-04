# FatSecret OAuth 2.0 Proxy Server - Complete Guide

## Overview

The FatSecret OAuth 2.0 Proxy is a **pass-through proxy** that:

1. **Manages OAuth 2.0 Tokens**
   - Authenticates with FatSecret using your credentials
   - Maintains valid access tokens
   - Auto-refreshes tokens before expiry
   - Handles token caching and lifecycle

2. **Forwards All FatSecret Requests**
   - Accepts requests from your mobile app
   - Adds authentication to each request
   - Forwards to FatSecret API
   - Returns results to mobile app

3. **Provides Single Whitelisting Point**
   - Gets a static IP from deployment platform
   - Whitelist this IP on FatSecret once
   - All user requests go through this IP
   - No need to whitelist individual mobile IPs

## Architecture

```
Multiple Mobile Users
        ↓ HTTPS
    ┌───┴───┐
    │       │
   User1  User2  User3
    │       │
    └───┬───┘
        ↓
  FatSecret OAuth Proxy (Static IP: 1.2.3.4)
        ↓ HTTP (from whitelisted IP)
   FatSecret API
```

## What the Proxy Does

### Request Flow

```
Mobile App Request:
  GET /food.search.v3.1?search_expression=coke

        ↓

Proxy Receives Request:
  1. Gets valid access token (auto-refresh if needed)
  2. Adds token to request: ?search_expression=coke&access_token=xyz
  3. Forwards to FatSecret API
  4. Receives response from FatSecret

        ↓

Proxy Returns Response:
  {
    "foods": [
      { "food_id": 123, "food_name": "Coca-Cola", ... },
      ...
    ]
  }
```

### Token Lifecycle

```
1. Server starts
   ├─ Request access token from FatSecret
   ├─ Get: access_token, expires_in (3600 seconds)
   └─ Schedule refresh in 55 minutes (60 seconds before expiry)

2. Token is used for requests
   ├─ Add to query: &access_token={token}
   ├─ Forward to FatSecret
   └─ Return results

3. Token about to expire
   ├─ 5 minutes before expiry, auto-refresh
   ├─ Request new token
   ├─ Schedule next refresh
   └─ Continue requests with new token

4. On error
   ├─ If 401 Unauthorized, force token refresh
   ├─ Retry request with new token
   └─ Continue
```

## Endpoints

### Health Check
```
GET /health
Response: {
  "status": "healthy",
  "service": "FatSecret OAuth Proxy",
  "token": {
    "status": "valid",
    "expires_in": 3600,
    "seconds_remaining": 3245
  }
}
```

### Token Info (Debug)
```
GET /token
Response: {
  "token_info": {
    "status": "valid",
    "access_token": "xyz...",
    "expires_in": 3600,
    "seconds_remaining": 3245,
    "issued_at": "2026-02-03T10:30:00.000Z"
  }
}
```

### Food Search (Example - forwards to FatSecret)
```
GET /food.search.v3.1?search_expression=coke
→ Proxy adds access_token automatically
→ Forwards to: https://platform.fatsecret.com/rest/food.search.v3.1?search_expression=coke&access_token=xyz
→ Returns FatSecret response
```

### Any FatSecret Endpoint
```
GET  /food.get.v3.1?food_id=12345
GET  /recipe.get.v3.1?recipe_id=67890
GET  /profile.get?user_id=xyz
POST /food.log.add_v2 (with body)
... etc (all FatSecret endpoints work)
```

## Configuration

### Environment Variables

```bash
# Required
FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0
FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f

# Optional
PORT=8080  # Default: 8080
```

### Deployment Platforms

#### Railway
```bash
# Set variables in Railway dashboard:
FATSECRET_CLIENT_ID=...
FATSECRET_CLIENT_SECRET=...
PORT=8080
```

#### Heroku
```bash
heroku create fatsecret-proxy
heroku config:set FATSECRET_CLIENT_ID=...
heroku config:set FATSECRET_CLIENT_SECRET=...
git push heroku main
```

#### DigitalOcean
```bash
# Set in App Settings
FATSECRET_CLIENT_ID=...
FATSECRET_CLIENT_SECRET=...
PORT=8080
```

## Usage in Mobile App

### 1. Initialize
```dart
import 'package:metadash/data/datasources/fatsecret_remote_datasource.dart';

final fatsecretDatasource = FatSecretRemoteDatasource(
  backendUrl: 'https://your-proxy-url.com',  // e.g., https://fatsecret-proxy.herokuapp.com
);
```

### 2. Make Requests
```dart
// Search foods
final results = await fatsecretDatasource.searchFoods('coke');

// Get food details
final nutrition = await fatsecretDatasource.getFoodNutrition(12345);

// Get recipe
final recipe = await fatsecretDatasource.getRecipe(67890);
```

### 3. Error Handling
```dart
try {
  final results = await fatsecretDatasource.searchFoods('coke');
} catch (e) {
  if (e.toString().contains('IP restricted')) {
    // Proxy IP not whitelisted
  } else if (e.toString().contains('Unauthorized')) {
    // Token refresh failed
  } else if (e.toString().contains('timeout')) {
    // Request took too long
  }
}
```

## Deployment Steps

### Step 1: Choose Platform

**Railway (Recommended)**
- Simplest deployment
- Auto static IP
- Free with GitHub account

**Heroku**
- Traditional choice
- Paid static IP add-on needed
- Good documentation

**DigitalOcean**
- $5/month
- Reliable
- Static IP included

### Step 2: Deploy Backend

**Create Dart Project**
```bash
dart create -t console fatsecret_proxy
cd fatsecret_proxy
```

**Add Dependencies** (pubspec.yaml)
```yaml
dependencies:
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  http: ^1.1.0
```

**Copy Server Code**
```bash
# Copy docs/fatsecret_oauth_proxy.dart to bin/main.dart
cp ../metadash/docs/fatsecret_oauth_proxy.dart bin/main.dart
```

**Deploy to Platform**

Railway:
```bash
git init
git add .
git commit -m "Initial commit"
git push -u origin main
# Connect to Railway in dashboard
```

Heroku:
```bash
heroku create fatsecret-proxy
heroku config:set FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0
heroku config:set FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
git push heroku main
```

### Step 3: Get Static IP

**Railway**
- Dashboard → Settings → Public URL
- IP visible in URL or networking section

**Heroku**
- Need to purchase static IP add-on
- Or use API endpoint IP

**DigitalOcean**
- Dashboard → App Platform → Networking
- Static IP assigned automatically

### Step 4: Whitelist on FatSecret

1. Go to https://platform.fatsecret.com/my-account/ip-restrictions
2. Sign in
3. Click "Add IP Address"
4. Paste your server's public IP
5. Save

**Note**: May take up to 24 hours to take effect

### Step 5: Update Mobile App

```dart
// Replace with your actual proxy URL
const backendUrl = 'https://your-proxy-url.com';

final fatsecretDatasource = FatSecretRemoteDatasource(
  backendUrl: backendUrl,
);
```

### Step 6: Test

```bash
# Test health endpoint
curl https://your-proxy-url.com/health

# Test token info
curl https://your-proxy-url.com/token

# Test search
curl "https://your-proxy-url.com/food.search.v3.1?search_expression=coke"
```

## Monitoring

### Check Health

```bash
curl https://your-proxy-url.com/health
```

Response:
```json
{
  "status": "healthy",
  "token": {
    "status": "valid",
    "seconds_remaining": 3200
  }
}
```

### Check Token Status

```bash
curl https://your-proxy-url.com/token
```

Response:
```json
{
  "token_info": {
    "status": "valid",
    "seconds_remaining": 3200,
    "expires_in": 3600
  }
}
```

### View Logs

**Railway**: Dashboard → Logs  
**Heroku**: `heroku logs -t`  
**DigitalOcean**: Dashboard → Logs

### Expected Log Output

```
[Token] Refreshing access token...
[Token] ✅ Token refreshed
[Token]    Expires in: 3600s
[Token] 📅 Next refresh in: 3540s
[Proxy] GET /food.search.v3.1?search_expression=coke
[Proxy] ✅ 200 /food.search.v3.1?search_expression=coke
```

## Troubleshooting

### "Backend unreachable"
```bash
# Verify proxy is running
curl https://your-proxy-url.com/health

# If failed:
- Check platform dashboard (deployment status)
- Check logs for errors
- Verify environment variables are set
```

### "IP restricted" or "403 Forbidden"
```bash
# Whitelist isn't active yet
- Wait up to 24 hours after adding IP
- Verify IP on FatSecret dashboard
- Try from proxy server: ssh to server and curl FatSecret

# If still failing:
- Double-check IP is correct
- Contact FatSecret support
```

### "Invalid token" or "401 Unauthorized"
```bash
# Token refresh failed
- Check credentials in environment variables
- Verify they're correct in FatSecret Developer Console
- Check proxy logs for OAuth errors
- Restart proxy server

# Restart command depends on platform:
Heroku:  heroku restart
Railway: Redeploy from dashboard
DigitalOcean: Redeploy from dashboard
```

### "Timeout" or Slow Requests
```bash
# Requests taking too long
- Check FatSecret API status (might be slow)
- Check network latency
- Increase timeout in mobile app (currently 15s)

# In fatsecret_remote_datasource.dart:
const Duration(seconds: 15) → const Duration(seconds: 30)
```

### "Empty or no results"
```bash
# Query might be too specific
- Try simpler search terms
- Verify FatSecret has the food in database
- Check mobile app is using correct backend URL
```

## Security Best Practices

✅ **DO**
- Store credentials in environment variables
- Use HTTPS for all mobile requests
- Use IP whitelisting on FatSecret
- Monitor logs for errors
- Rotate credentials if compromised
- Use strong credentials

❌ **DON'T**
- Hardcode credentials in code
- Commit credentials to git
- Use HTTP (only HTTPS)
- Share credentials in chat/email
- Leave debug mode on in production
- Expose proxy to unauthorized IPs

## Performance Optimization

### Token Caching
- ✅ Tokens cached in memory
- ✅ Auto-refresh 5 minutes before expiry
- ✅ No unnecessary OAuth calls

### Request Forwarding
- ✅ Direct pass-through (minimal overhead)
- ✅ Query parameters preserved
- ✅ Request method preserved (GET/POST/PUT/DELETE)
- ✅ Headers passed through

### Scaling
- Add caching layer for repeated searches
- Use CDN for static responses
- Load balance multiple proxy instances
- Monitor API quota usage

## Cost Analysis

| Aspect | Cost | Notes |
|--------|------|-------|
| Railway | Free tier | 100 GB bandwidth/month |
| Heroku | $7/month static IP | Platform $50/month (optional) |
| DigitalOcean | $5/month | Smallest droplet includes static IP |
| FatSecret API | Free | Rate limited, generous free tier |
| **Total** | **$0-12/month** | Most projects under $10 |

## Monitoring Checklist

- [ ] Check health endpoint daily
- [ ] Monitor token refresh in logs
- [ ] Alert on 401/403 errors
- [ ] Track request latency
- [ ] Monitor error rates
- [ ] Check IP whitelist status
- [ ] Verify token validity
- [ ] Review FatSecret quota usage

## Production Deployment Checklist

- [ ] Environment variables set correctly
- [ ] Credentials verified with FatSecret
- [ ] Server deployed and running
- [ ] Health endpoint responds
- [ ] Token refresh working
- [ ] IP whitelisted on FatSecret
- [ ] Mobile app configured with proxy URL
- [ ] Test search working end-to-end
- [ ] Error handling in place
- [ ] Logging configured
- [ ] Monitoring alerts set up
- [ ] HTTPS enforced
- [ ] CORS properly configured
- [ ] Rate limiting considered (future)

---

**Next Steps**:
1. Deploy proxy to your platform
2. Get static IP
3. Whitelist IP on FatSecret
4. Update mobile app
5. Test end-to-end
6. Monitor for 24 hours
