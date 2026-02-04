# FatSecret Backend Proxy - Complete Integration Guide

## Architecture Overview

```
Mobile App (metadash)
    ↓ HTTPS
Backend Proxy Server (Static IP)
    ↓ HTTP  
FatSecret API
```

## Why This Approach?

✅ Mobile apps have dynamic IPs → Can't whitelist individual users  
✅ Backend has static IP → Can be whitelisted on FatSecret  
✅ Credentials secure → Never exposed to mobile app  
✅ Token management centralized → One place to refresh OAuth tokens  
✅ Optional → Works alongside USDA and OFF integrations  

## Setup Steps

### 1. Create Backend Proxy Server

Choose one:

#### Option A: Deploy to Railway (Recommended - Free)

```bash
# 1. Go to https://railway.app and sign up
# 2. Create new project
# 3. Upload code to GitHub
# 4. Connect to Railway
# 5. Railway generates a URL with static IP
# 6. Get IP from Railway dashboard
```

#### Option B: Deploy to Heroku (Free tier ending soon)

```bash
# 1. Create Heroku account at https://www.heroku.com
# 2. Install Heroku CLI: brew install heroku
# 3. In backend project directory:
cd backend/
heroku login
heroku create fatsecret-proxy
heroku config:set FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0
heroku config:set FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
git push heroku main

# 4. Get URL: https://fatsecret-proxy.herokuapp.com
# 5. Find static IP in Heroku dashboard
```

#### Option C: Deploy to DigitalOcean (~$5/month - Most reliable)

```bash
# 1. Create DigitalOcean account
# 2. Create new App from GitHub repo
# 3. Set environment variables:
#    - FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0
#    - FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
# 4. Deploy - DigitalOcean assigns static IP
```

### 2. Get Static IP Address

After deployment, get your server's public IP:

```bash
# Railway: Dashboard → Settings → Public URL or IP
# Heroku: Paid add-on needed (Quoting Apps) for static IP
# DigitalOcean: Dashboard → Networking → Static IPs
```

### 3. Whitelist IP in FatSecret Dashboard

1. Go to https://platform.fatsecret.com/my-account/ip-restrictions
2. Click "Add IP Address"
3. Enter your backend server's static IP
4. Save

Now your backend can make requests to FatSecret without restriction!

### 4. Configure Mobile App

Update your mobile app to use the backend proxy:

```dart
// In main.dart or app initialization:
import 'package:metadash/data/datasources/fatsecret_remote_datasource.dart';
import 'package:metadash/data/repositories/fatsecret_repository.dart';

final fatsecretDatasource = FatSecretRemoteDatasource(
  backendUrl: 'https://fatsecret-proxy.herokuapp.com', // Replace with your URL
);

final fatsecretRepository = FatSecretRepository(
  remoteDatasource: fatsecretDatasource,
);
```

### 5. Integrate Into Search Flow

In your search screen:

```dart
// Search multiple sources in parallel
final localResults = await searchRepository.search(query);
final fatsecretResults = await fatsecretRepository.searchFoods(query);

// Combine and deduplicate
final allResults = [...localResults, ...fatsecretResults];
final deduped = deduplicateFoods(allResults);

// Emit to UI
emit(SearchSuccess(results: deduped));
```

## Backend Server Code

The backend proxy code is included in:
- `lib/services/fatsecret_client.dart` - OAuth handling
- `docs/fatsecret_backend_server.dart` - Complete server implementation

### To run locally for testing:

```bash
# 1. Create backend project
dart create -t console fatsecret_backend
cd fatsecret_backend

# 2. Add dependencies to pubspec.yaml
dependencies:
  shelf: ^1.4.0
  shelf_router: ^1.1.0

# 3. Copy fatsecret_backend_server.dart to bin/main.dart

# 4. Run with credentials
dart run \
  --define=FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0 \
  --define=FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f

# Server runs at http://localhost:8080
```

## API Endpoints

Your backend provides these endpoints for the mobile app:

### Search Foods
```
GET /api/foods/search?q=coke
Response: { "foods": [...] }
```

### Get Food Nutrition
```
GET /api/foods/12345
Response: { "food": { "calories": 42, ... } }
```

### Get Recipe
```
GET /api/recipes/12345
Response: { "recipe": { ... } }
```

### Health Check
```
GET /health
Response: { "status": "ok" }
```

## Security

✅ **Credentials never in mobile app** - Only stored in .env on server  
✅ **CORS enabled** - Mobile app can make requests  
✅ **HTTPS enforced** - All communication encrypted  
✅ **IP whitelisting** - Only your server can access FatSecret  

## Troubleshooting

### "Connection refused" or "Backend unreachable"

```dart
// 1. Verify backend is running
curl https://your-backend-url/health

// 2. Check URL in mobile app
final fatsecretDatasource = FatSecretRemoteDatasource(
  backendUrl: 'https://your-actual-backend-url',
);

// 3. Verify backend has environment variables set
echo $FATSECRET_CLIENT_ID
echo $FATSECRET_CLIENT_SECRET
```

### "Unauthorized" or "Invalid token"

```
// 1. Check credentials in backend dashboard
// 2. Verify IP is whitelisted on FatSecret
// 3. Restart backend server
// 4. Check backend logs for OAuth errors
```

### "IP restricted" or "403 Forbidden"

```
// 1. Verify your server's static IP is correct
// 2. Whitelist in FatSecret dashboard
// 3. Wait up to 24 hours for DNS to propagate
// 4. Contact FatSecret support if issue persists
```

## Environment Variables (Server)

Store in your deployment platform:

```env
FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0
FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
```

**Railway**: Variables → Add Variable  
**Heroku**: Settings → Config Vars  
**DigitalOcean**: App Settings → Environment  

## Monitoring

Monitor backend health:

```bash
# Check if server is running
curl https://your-backend-url/health

# Look at logs
heroku logs -t # Heroku
railway logs # Railway
```

## Cost Analysis

| Provider | Cost | Static IP | Notes |
|----------|------|-----------|-------|
| Railway | Free | Included | Recommended |
| Heroku | Free (platform) | $7/mo addon needed | Good for learning |
| DigitalOcean | $5/mo | Included | Most reliable |
| AWS Lambda | Pay-per-use | AWS IP | For high traffic |

## Next Steps

1. ✅ Choose deployment platform
2. ✅ Deploy backend server
3. ✅ Get static IP address
4. ✅ Whitelist IP on FatSecret
5. ✅ Update mobile app with backend URL
6. ✅ Test search functionality
7. ✅ Monitor and optimize

---

**Need help?**  
- FatSecret API docs: https://platform.fatsecret.com/api/Default.aspx
- Railway docs: https://docs.railway.app
- DigitalOcean docs: https://docs.digitalocean.com/products/app-platform/
