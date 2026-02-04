# 🚀 Step-by-Step Railway Deployment Guide

**Time Required**: 10-15 minutes  
**Difficulty**: Easy  
**Cost**: FREE (Railway free tier is sufficient)

---

## ✅ Prerequisites

Before starting, ensure you have:
- [ ] GitHub account (you have this ✅)
- [ ] Railway account (create at https://railway.app)
- [ ] Metadash repository uploaded to GitHub
- [ ] FatSecret credentials (you have these ✅)

---

## 🚀 Deployment Steps

### Step 1: Create Railway Account (2 minutes)

1. Go to: **https://railway.app**
2. Click **"Start for Free"**
3. Sign up with **GitHub** (recommended)
4. Authorize Railway to access your GitHub account
5. You should see the Railway dashboard

**Dashboard Preview**: You'll see "Projects", "New Project" button, etc.

---

### Step 2: Create New Project (1 minute)

1. **Railway Dashboard** → Click **"New Project"**
2. Select **"Deploy from GitHub repo"**
3. Authorize Railway to access your GitHub repositories

**Expected**: List of your GitHub repositories

---

### Step 3: Select Your Repository (1 minute)

1. Search for: **metadash**
2. Click on **metadash** repository
3. Click **"Deploy"**

**What Happens Next**: Railway will detect the project type

---

### Step 4: Configure Build Settings (2 minutes)

Railway should auto-detect it's a Dart/Flutter project. If prompted:

**Build Configuration:**
- **Root Directory**: `deployment/` ⭐ CRITICAL
- **Build Command**: `dart pub get`
- **Start Command**: `dart run bin/main.dart`
- **Node/Dart Version**: Leave defaults

**If Not Prompted**:
1. Go to **Settings** → **Build Configuration**
2. Set as above

---

### Step 5: Set Environment Variables (2 minutes)

This is **critical** - the proxy needs FatSecret credentials.

1. **Railway Dashboard** → Your Project
2. → **Variables** (or **Env**)
3. Click **"Add Variable"**

**Add These 3 Variables:**

```
FATSECRET_CLIENT_ID = b9f7e7de97b340b7915c3ac9bab9bfe0

FATSECRET_CLIENT_SECRET = b788a80bfaaf4e569e811a381be3865f

PORT = 8080
```

After adding each, click **"Save"** or **"Add"**

**Verification**: All 3 variables should appear in the list

---

### Step 6: Deploy (3-5 minutes)

1. **Railway Dashboard** → Your Project → **Deploy** (or **Redeploy**)
2. Watch the build progress:
   - "Installing dependencies..." → "Building..." → "Deploying..." → "Online"
3. Wait for status to show **"Online"** (green ✅)

**What's Happening**:
- Railway downloads Dart SDK
- Installs dependencies (shelf, http, etc.)
- Compiles your Dart code
- Starts the proxy server

**Typical Duration**: 2-3 minutes

---

### Step 7: Get Backend URL (1 minute)

Once status is **"Online"**:

1. **Railway Dashboard** → Your Project
2. Look for **"Domain"** or **"URL"** section
3. Copy the URL (e.g., `https://fatsecret-proxy-production.up.railway.app`)
4. **Save this URL** - you'll need it

**Format**: `https://[project-name]-[random-id].up.railway.app`

---

### Step 8: Get Static IP (1 minute)

1. **Railway Dashboard** → Your Project → **Settings**
2. Look for **"Network"** or **"Static IP"** section
3. Copy the **Static IP** (e.g., `203.0.113.45`)
4. **Save this IP** - you'll need it for FatSecret

**Note**: It may take a few minutes to appear after first deploy

---

### Step 9: Verify Backend is Working (1 minute)

Test the health endpoint:

```bash
curl https://your-railway-url/health
```

**Expected Response**:
```json
{
  "status": "ok",
  "token_valid": false,
  "expires_in": 0
}
```

**Note**: `token_valid: false` is expected until IP is whitelisted

---

### Step 10: Whitelist IP on FatSecret (2 minutes, 0-24h activation)

**IMPORTANT**: Do this while waiting for Railway to be fully up

1. Go to: **https://platform.fatsecret.com/my-account/ip-restrictions**
2. Click **"Add New IP"**
3. Enter: `[your-static-ip]/32`
   - Example: `203.0.113.45/32`
4. Click **"Add"** or **"Submit"**
5. Status will show: **"Pending"**
6. FatSecret will email when **"Active"**

**Timeline**: 
- Immediate: Request submitted
- 0-24 hours: FatSecret activates
- You'll receive email confirmation

---

### Step 11: Verify Token After IP Whitelisting (1 minute)

Once FatSecret activates (you'll get an email):

```bash
curl https://your-railway-url/health
```

**Expected Response** (after IP is active):
```json
{
  "status": "ok",
  "token_valid": true,
  "expires_in": 3600
}
```

**Note**: `token_valid: true` means IP is whitelisted! ✅

---

### Step 12: Update Mobile App (2 minutes)

Now update the Flutter app to use your backend:

1. **Open**: `lib/presentation/bloc/food_search_bloc.dart`

2. **Find** (around line 20):
```dart
_repository = SearchRepository.withFatSecret(
  backendUrl: 'http://localhost:8080', // ← CHANGE THIS
)
```

3. **Replace** with your Railway URL:
```dart
_repository = SearchRepository.withFatSecret(
  backendUrl: 'https://your-railway-url.com', // ← YOUR URL
)
```

4. **Rebuild app**:
```bash
flutter clean
flutter pub get
flutter run
```

---

### Step 13: Test End-to-End (2 minutes)

1. **Open metadash app** (running from `flutter run`)
2. **Search for a food**: "chicken"
3. **Verify results**:
   - Should see 50+ foods
   - From FatSecret
   - With nutrition data
4. **Check logs** for:
   ```
   ✅ FatSecret search successful
   ✅ Found 45 foods from FatSecret
   ```

**Success Indicators**:
- ✅ Results appear quickly
- ✅ Multiple foods with nutrition
- ✅ No errors in console
- ✅ Logs show FatSecret source

---

## ✅ Deployment Checklist

- [ ] Railway account created
- [ ] GitHub repository uploaded
- [ ] New Railway project created
- [ ] Root directory set to `deployment/`
- [ ] Environment variables set (3 total)
- [ ] Deployment status shows "Online"
- [ ] Backend URL saved
- [ ] Static IP saved
- [ ] IP whitelisted on FatSecret
- [ ] Email received from FatSecret (IP active)
- [ ] Mobile app updated with backend URL
- [ ] App rebuilt and tested
- [ ] Search returns FatSecret results

---

## 🆘 Troubleshooting

### Deployment Fails

**Error**: "Build failed" or similar

**Solution**:
1. Check Railway logs (Dashboard → Project → Logs)
2. Common issues:
   - Root directory wrong (should be `deployment/`)
   - Environment variables missing
   - Dart SDK version issue
3. Try **Redeploy** from Railway dashboard

### Backend URL Not Found

**Error**: "Cannot access https://your-url..."

**Solution**:
1. Go to Railway dashboard
2. Check project status (should be "Online")
3. Copy URL again carefully (no typos)
4. Wait 2-3 minutes after deploy

### Token Still Says "token_valid: false"

**Cause**: IP not yet whitelisted on FatSecret

**Solution**:
1. Check FatSecret status: https://platform.fatsecret.com/my-account/ip-restrictions
2. Should show "Active" (not "Pending")
3. Wait up to 24 hours if still pending
4. Check email for FatSecret confirmation

### Mobile App Still Gets 400 Error

**Cause**: 
1. App using old backend URL
2. IP not whitelisted yet
3. Wrong URL in code

**Solution**:
1. Verify backend URL in `food_search_bloc.dart`
2. Run `flutter clean && flutter pub get`
3. Rebuild with `flutter run`
4. Check FatSecret IP status
5. Try health endpoint in browser

---

## 📊 Expected URLs & IPs

After successful deployment, you should have:

**Backend URL** (example):
```
https://fatsecret-proxy-production.up.railway.app
```

**Static IP** (example):
```
203.0.113.45
```

**Mobile app calls**:
```
https://fatsecret-proxy-production.up.railway.app/food.search.v3.1?search_expression=chicken
```

---

## ⏱️ Timeline

| Step | Time | What's Happening |
|------|------|------------------|
| 1-3 | 3 min | Setup & authorization |
| 4-6 | 5 min | Configuration |
| 7-9 | 10 min | Deploy, get URL, verify |
| 10 | 2 min | Whitelist IP |
| 11 | 0-24h | FatSecret activation (wait) |
| 12 | 2 min | Update mobile app |
| 13 | 2 min | Test |
| **Total** | **15-25 min** | **+ 0-24h wait for FatSecret** |

---

## ✨ You're All Set!

Once complete, your metadash app will:
- ✅ Search FatSecret first (150,000+ foods)
- ✅ Auto-fallback to USDA/OpenFoodFacts
- ✅ Show clean, deduplicated results
- ✅ Have secure OAuth token management
- ✅ Never expose credentials to mobile

**Start with Step 1 above and follow each step in order. You've got this!** 🚀
