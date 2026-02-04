# Railway Deployment - Step by Step

Railway is the **easiest and fastest** way to deploy (5 minutes, free tier available).

## Prerequisites

- Dart installed locally (`dart --version`)
- Git installed (`git --version`)
- GitHub account
- Free Railway.app account

## Step 1: Test Locally (2 minutes)

```bash
cd fatsecret-proxy

# Install dependencies
dart pub get

# Run with your credentials
dart run \
  --define FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0 \
  --define FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
```

**Expected output:**
```
✅ FatSecret OAuth Proxy started on http://0.0.0.0:8080
📍 Health check: http://localhost:8080/health
```

Test in another terminal:
```bash
curl http://localhost:8080/health
```

**Expected response:**
```json
{"status":"ok","token_valid":true,"expires_in":3600}
```

## Step 2: Create GitHub Repository (1 minute)

```bash
# Initialize git
git init

# Add all files
git add .

# Commit
git commit -m "FatSecret OAuth proxy for metadash"

# Create repo on GitHub
# Go to https://github.com/new
# Name it: fatsecret-proxy
# Do NOT initialize with README (we have one)

# Add remote and push
git remote add origin https://github.com/YOUR_USERNAME/fatsecret-proxy.git
git branch -M main
git push -u origin main
```

## Step 3: Connect to Railway (2 minutes)

1. Go to https://railway.app
2. Click **"Login with GitHub"**
3. Authorize Railway to access your GitHub account
4. Click **"Create New Project"**
5. Select **"Deploy from GitHub repo"**
6. Choose **fatsecret-proxy** repository
7. Railway will auto-detect Dart project

## Step 4: Set Environment Variables (1 minute)

In Railway dashboard:

1. Go to your project → **Variables** tab
2. Click **"New Variable"**
3. Add:

```
Name: FATSECRET_CLIENT_ID
Value: b9f7e7de97b340b7915c3ac9bab9bfe0
```

4. Click **"New Variable"** again
5. Add:

```
Name: FATSECRET_CLIENT_SECRET
Value: b788a80bfaaf4e569e811a381be3865f
```

6. Click **"Save"**

## Step 5: Deploy (Automatic)

Railway will automatically deploy when you push to GitHub.

**Check deployment status:**
1. Go to your Railway project
2. Click **"Services"** → **"fatsecret-proxy"**
3. Watch logs scroll by

**Expected log:**
```
✅ FatSecret OAuth Proxy started on http://0.0.0.0:8080
📍 Health check: http://localhost:8080/health
🔐 Token endpoint: http://localhost:8080/token
🔄 All other paths forwarded to FatSecret API
```

## Step 6: Get Your URL (Immediate)

1. In Railway dashboard → **fatsecret-proxy** service
2. Look for **"Domains"** section
3. Copy the URL (looks like: `https://your-app.railway.app`)

This is your **backend URL**!

## Step 7: Get Static IP (Immediate)

1. In Railway dashboard → **Settings** → **Network**
2. Find your static IP (or IP range)
3. Copy it

This is what you **whitelist on FatSecret**!

## Step 8: Whitelist on FatSecret (0-24 hours)

1. Go to https://platform.fatsecret.com/my-account/ip-restrictions
2. Click **"Add IP"**
3. Paste your static IP
4. Click **"Save"**
5. Wait up to 24 hours (usually much faster)

## Step 9: Update Mobile App (1 minute)

In your Flutter app:

```dart
// In main.dart or wherever you initialize SearchRepository
const backendUrl = 'https://your-app.railway.app';

final searchRepo = SearchRepository.withFatSecret(
  backendUrl: backendUrl,
);
```

## Step 10: Test (2 minutes)

```bash
# Test health endpoint
curl https://your-app.railway.app/health

# Expected:
# {"status":"ok","token_valid":true,"expires_in":3600}

# Test proxy is working
curl "https://your-app.railway.app/food.search.v3.1?search_expression=coke"

# Should return FatSecret results as JSON
```

## Step 11: Monitor (Ongoing)

In Railway dashboard:

1. Click **"Logs"** tab
2. Watch for:
   - ✅ `Token refreshed` - Normal operation
   - ✅ `FatSecret found X results` - Working correctly
   - ❌ `IP restricted` - Need to wait for whitelist
   - ❌ `Invalid credentials` - Check env vars

## Troubleshooting

### "IP restricted" error
```json
{"error":"IP restricted"}
```
**Solution**: Whitelist not activated yet. Wait 24 hours. Check FatSecret dashboard.

### "Invalid credentials" error
```json
{"error":"Invalid credentials"}
```
**Solution**: Check environment variables:
1. Railway dashboard → Variables
2. Verify `FATSECRET_CLIENT_ID` and `FATSECRET_CLIENT_SECRET`
3. Restart service (Railway → Redeploy)

### Deployment stuck
**Solution**: Check logs (Railway → Logs). Look for:
- Build errors → Fix and push again
- Startup errors → Check env vars
- Hanging → Try redeploying

### Can't connect to backend URL
**Solution**:
1. Verify URL is correct
2. Try: `curl https://your-app.railway.app/health`
3. Check Railway service is running (not crashed)
4. Wait a few minutes for deployment to fully finish

## Making Changes

After initial deployment, to make code changes:

```bash
# Make changes to code
vim bin/main.dart

# Commit and push
git add .
git commit -m "Fix: token refresh timing"
git push origin main

# Railway automatically redeploys!
# Check logs to confirm deployment
```

## Production Checklist

- [x] Code compiles locally
- [x] Tests pass
- [x] Environment variables set
- [x] Health endpoint works
- [x] Token endpoint works
- [x] Proxy forwards requests correctly
- [x] IP whitelisted on FatSecret
- [x] Mobile app updated with backend URL
- [x] End-to-end search works
- [x] Logs show normal operation
- [x] Monitoring set up (email on errors)

## Cost

- **Free tier**: 500 hours/month (enough for 1 always-running service)
- **Pro tier**: $5/month for additional features
- **For this proxy**: Free tier is sufficient

## Next Steps

1. After deployment succeeds, verify everything works
2. Check metadash app searches return FatSecret results
3. Monitor logs for 24 hours
4. Set up email alerts if available

## Support

**Railway Documentation**: https://docs.railway.app/  
**Dart on Railway**: https://docs.railway.app/deploy/native-environments#dart

---

**Estimated time to full deployment: 15 minutes**  
**Most of that is waiting for IP whitelist activation on FatSecret (0-24 hours)**
