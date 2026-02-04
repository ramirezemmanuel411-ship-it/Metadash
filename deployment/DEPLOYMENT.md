# FatSecret OAuth Proxy - Complete Deployment Guide

**Estimated Time**: 15 minutes (mostly waiting for IP whitelist)  
**Difficulty**: Easy  
**Platform**: Railway recommended (easiest & free)

---

## Overview

This proxy server handles OAuth 2.0 authentication with FatSecret, allowing your metadash app to search for foods without exposing API credentials.

## Architecture

```
metadash app (iPhone/Android)
        ↓ HTTPS (your credentials never exposed)
OAuth Proxy Server (this deployment)
        ├─ Token Manager (auto-refresh, caching)
        ├─ Request Router
        └─ Error Handler
        ↓ HTTP (IP-whitelisted access)
FatSecret API
```

## Deployment Options

### 🚀 Railway (RECOMMENDED - Easiest)

**Pros**: 
- Free tier (500 hours/month)
- Auto-deploys on git push
- One-click GitHub integration
- 15-minute setup

**Cons**: 
- None, honestly. It's the best option for this.

**Time**: 15 minutes total

[→ Go to Railway Guide](DEPLOY_RAILWAY.md)

### 💜 Heroku (Still Easy)

**Pros**:
- Simple deployment
- Free tier (500 hours/month with limitations)
- Familiar to many developers

**Cons**:
- Requires Procfile setup
- Slower cold starts

**Time**: 20 minutes total

```bash
heroku create your-app-name
heroku config:set FATSECRET_CLIENT_ID=...
heroku config:set FATSECRET_CLIENT_SECRET=...
git push heroku main
```

### 🌊 DigitalOcean (More Control)

**Pros**:
- Very reliable
- Good documentation
- App Platform (managed Docker)

**Cons**:
- Costs $5-12/month (but very stable)
- Slightly more setup

**Time**: 25 minutes total

### 🖥️ Local Testing (No Deployment)

Perfect for testing before deploying to production.

```bash
dart pub get
dart run --define FATSECRET_CLIENT_ID=... --define FATSECRET_CLIENT_SECRET=...
```

---

## Step-by-Step: Railway Deployment (Recommended)

### Prerequisites (2 minutes)

Verify you have:
- ✅ Dart installed (`dart --version`)
- ✅ Git installed (`git --version`)
- ✅ GitHub account
- ✅ FatSecret credentials (from phase 2)

### 1. Test Locally (3 minutes)

```bash
# Get dependencies
dart pub get

# Run with credentials
dart run \
  --define FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0 \
  --define FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
```

**Expected output**:
```
✅ FatSecret OAuth Proxy started on http://0.0.0.0:8080
📍 Health check: http://localhost:8080/health
🔐 Token endpoint: http://localhost:8080/token
🔄 All other paths forwarded to FatSecret API
```

**Test it** (in another terminal):
```bash
curl http://localhost:8080/health
```

**Expected response**:
```json
{"status":"ok","token_valid":true,"expires_in":3600}
```

✅ **Local testing complete!**

### 2. Create GitHub Repository (2 minutes)

```bash
# Initialize git
git init

# Add all files
git add .

# First commit
git commit -m "FatSecret OAuth proxy for metadash"

# Create repo at https://github.com/new
# Name: fatsecret-proxy
# Do NOT check "Initialize with README"

# Connect local repo to GitHub
git remote add origin https://github.com/YOUR_USERNAME/fatsecret-proxy.git
git branch -M main
git push -u origin main
```

✅ **GitHub repository created!**

### 3. Connect to Railway (2 minutes)

1. Go to **https://railway.app**
2. Click **"Login with GitHub"** (authorize Railway)
3. Click **"Create New Project"**
4. Click **"Deploy from GitHub repo"**
5. Select **fatsecret-proxy** from your repos
6. Railway detects it's a Dart project and auto-configures ✅

### 4. Set Environment Variables (1 minute)

**In Railway Dashboard** → Your Project → Variables:

| Name | Value |
|------|-------|
| `FATSECRET_CLIENT_ID` | `b9f7e7de97b340b7915c3ac9bab9bfe0` |
| `FATSECRET_CLIENT_SECRET` | `b788a80bfaaf4e569e811a381be3865f` |

✅ **Variables set!**

### 5. Deploy (Automatic)

Railway automatically deploys! Watch the logs:

1. Go to your project in Railway
2. Click **"Services"** → **"fatsecret-proxy"**
3. Watch logs scroll

**Expected log output**:
```
✅ FatSecret OAuth Proxy started on http://0.0.0.0:8080
📍 Health check: http://localhost:8080/health
```

✅ **Deployed!**

### 6. Get Your Backend URL (Immediate)

1. In Railway dashboard → **fatsecret-proxy** → **Domains**
2. Copy the URL (looks like: `https://fatsecret-proxy-production.railway.app`)
3. **Save this URL** - you'll need it for the mobile app

### 7. Get Your Static IP (Immediate)

1. In Railway dashboard → **Settings** → **Network**
2. Find and copy your static IP address
3. **Save this IP** - you'll need it for FatSecret

### 8. Whitelist IP on FatSecret (0-24 hours)

1. Go to **https://platform.fatsecret.com/my-account/ip-restrictions**
2. Click **"Add IP"**
3. Paste your static IP from step 7
4. Click **"Save"**
5. ⏰ **Wait up to 24 hours** (usually faster)

🚨 **Important**: Your proxy **won't work** until this is done!

Check status:
```bash
curl https://your-proxy.railway.app/health

# Before whitelist:
# {"error":"IP restricted"}

# After whitelist:
# {"status":"ok","token_valid":true,"expires_in":3600}
```

### 9. Update Mobile App (1 minute)

In your Flutter app (metadash):

```dart
// In main.dart or wherever SearchRepository is initialized
const backendUrl = 'https://your-proxy-production.railway.app';

final searchRepository = SearchRepository.withFatSecret(
  backendUrl: backendUrl,
);

// Or if using BLoC provider
BlocProvider(
  create: (_) => FoodSearchBloc(
    repository: SearchRepository.withFatSecret(
      backendUrl: backendUrl,
    ),
  ),
  child: const FastFoodSearchScreen(),
)
```

### 10. Test End-to-End (2 minutes)

```bash
# Test health
curl https://your-proxy.railway.app/health

# Test search (after IP whitelist activated)
curl "https://your-proxy.railway.app/food.search.v3.1?search_expression=coke"

# Should return FatSecret results as JSON
```

In the app:
1. Run: `flutter run`
2. Search for "coke"
3. Should see results from FatSecret within 1-2 seconds
4. Check Railway logs → should see incoming requests

✅ **Deployment complete!**

---

## Verification Checklist

```bash
#!/bin/bash
# Copy this into verify.sh and run: bash verify.sh https://your-proxy.railway.app

# Or use the provided script:
bash verify.sh https://your-proxy.railway.app
```

- [ ] Health check returns 200 with `token_valid: true`
- [ ] Token endpoint returns access token with `expires_in`
- [ ] Search request returns FatSecret results (after IP whitelist)
- [ ] Mobile app searches work end-to-end
- [ ] No errors in Railway logs

---

## Troubleshooting

### "IP restricted" Error

```json
{"error":"IP restricted"}
```

**Cause**: IP whitelist not activated on FatSecret yet  
**Timeline**: 0-24 hours  
**Fix**: Wait, then test again  

Check status:
```bash
# Keep running this until it works
while true; do
  curl https://your-proxy.railway.app/health
  sleep 60
done
```

### "Invalid Credentials" Error

```json
{"error":"Invalid credentials"}
```

**Cause**: FATSECRET_CLIENT_ID or FATSECRET_CLIENT_SECRET is wrong  
**Fix**:
1. Railway → Variables
2. Double-check credentials
3. Restart service (Railway → Redeploy)

### Deployment Not Starting

**Cause**: Dart version or dependency issue  
**Fix**:
1. Check Railway logs for error message
2. Try local: `dart pub get && dart run`
3. If local works, try redeploying from Railway

### Cannot Reach Backend URL

**Cause**: URL is wrong or deployment crashed  
**Fix**:
1. Copy exact URL from Railway dashboard
2. Verify it with: `curl https://your-url.railway.app/health`
3. Check Railway logs for crashes
4. Wait a few minutes for deployment to fully complete

---

## Making Changes

After initial deployment, to update code:

```bash
# 1. Make changes
vim bin/main.dart

# 2. Commit and push
git add .
git commit -m "Fix: token refresh timing"
git push origin main

# 3. Railway auto-redeploys!
# 4. Check logs to verify new version is running
```

---

## Security Best Practices

✅ **Do**:
- Keep credentials in environment variables
- Use HTTPS for all requests
- Whitelist only necessary IPs
- Monitor logs for errors
- Rotate credentials periodically

❌ **Don't**:
- Commit .env file with real credentials
- Share proxy URL publicly
- Expose credentials in logs
- Use HTTP (only HTTPS)
- Keep outdated dependencies

---

## Production Monitoring

After deployment, monitor:

1. **Health Check** (every 5 minutes):
   ```bash
   curl https://your-proxy.railway.app/health
   ```

2. **Logs** (Railway dashboard → Logs):
   - Look for: `Token refreshed` ✅
   - Look for: `FatSecret found X results` ✅
   - Avoid: `IP restricted` ❌
   - Avoid: `Invalid credentials` ❌

3. **Error Rate**:
   - Should be < 1% in normal operation
   - Spikes indicate issues

4. **Response Time**:
   - Typical: 500-2000ms
   - If > 5000ms: FatSecret might be slow

---

## Cost Comparison

| Platform | Cost | Setup Time | Reliability |
|----------|------|-----------|-------------|
| **Railway** | Free (500 hrs/mo) | 15 min | ⭐⭐⭐⭐⭐ |
| **Heroku** | Free tier limited | 20 min | ⭐⭐⭐⭐ |
| **DigitalOcean** | $5-12/mo | 25 min | ⭐⭐⭐⭐⭐ |
| **AWS Lambda** | $1-10/mo | 45 min | ⭐⭐⭐⭐ |

**Recommendation**: Start with Railway (free, easiest)

---

## Next Steps After Deployment

1. ✅ Verify IP is whitelisted on FatSecret (24h max)
2. ✅ Test search in metadash app
3. ✅ Monitor logs for 24 hours
4. ✅ Set up error alerts (if available)
5. ✅ Document proxy URL for team
6. ✅ Plan backup if needed

---

## Support & Debugging

### Railroad Deployment Logs
```bash
# View real-time logs
# Railway Dashboard → Services → fatsecret-proxy → Logs
```

### Local Testing
```bash
# Test locally before deploying
dart run --define FATSECRET_CLIENT_ID=... --define FATSECRET_CLIENT_SECRET=...
```

### Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| Port already in use | Another service on 8080 | Use different port |
| Cannot parse JSON | Old token response format | Update token parsing |
| Connection timeout | FatSecret API down | Wait, check FatSecret status |
| 403 Forbidden | IP not whitelisted | Add IP to FatSecret |
| 401 Unauthorized | Invalid credentials | Check env vars |

---

**Ready? Let's deploy!** 🚀

**Start here**: [Railway Deployment (RECOMMENDED)](DEPLOY_RAILWAY.md)

---

## Questions?

See the full documentation in the root metadash repository:
- [FATSECRET_PROXY_QUICKSTART.md](../FATSECRET_PROXY_QUICKSTART.md)
- [FATSECRET_OAUTH_PROXY_GUIDE.md](../FATSECRET_OAUTH_PROXY_GUIDE.md)
- [FATSECRET_PRIMARY_DATABASE.md](../FATSECRET_PRIMARY_DATABASE.md)
