# FatSecret OAuth 2.0 Proxy - Quick Start (5 Minutes)

## What This Proxy Does

✅ **Manages OAuth tokens automatically** - No manual token refresh needed  
✅ **Forwards all FatSecret requests** - You don't add auth to each request  
✅ **Provides single IP for whitelisting** - One static IP covers all users  

## TL;DR - Deploy in 5 Steps

### Step 1: Create Backend (1 min)
```bash
dart create -t console fatsecret_proxy
cd fatsecret_proxy

# Copy server code
# Replace bin/main.dart with content from docs/fatsecret_oauth_proxy.dart
```

### Step 2: Add Dependencies (1 min)
```yaml
# pubspec.yaml
dependencies:
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  http: ^1.1.0
```

### Step 3: Deploy to Railway (2 min)
```bash
git init
git add .
git commit -m "Initial"

# Go to https://railway.app
# Connect GitHub repo
# Set environment variables in Railway dashboard:
#   FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0
#   FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
```

### Step 4: Get IP & Whitelist (1 min)
```bash
# Get static IP from Railway dashboard
# Copy the IP (e.g., 1.2.3.4)

# Go to https://platform.fatsecret.com/my-account/ip-restrictions
# Add your IP
```

### Step 5: Update Mobile App (1 min)
```dart
// In main.dart
const backendUrl = 'https://your-railway-url.com';

final fatsecretDatasource = FatSecretRemoteDatasource(
  backendUrl: backendUrl,
);
```

**Done! 🎉**

## Test It

```bash
# Health check
curl https://your-railway-url.com/health

# Search foods
curl "https://your-railway-url.com/food.search.v3.1?search_expression=coke"
```

## How It Works (30 seconds)

```
User App searches for "Coke"
    ↓
Proxy receives: GET /food.search.v3.1?search_expression=coke
    ├─ Gets token from TokenManager (cached, auto-refreshes)
    ├─ Adds token to request
    └─ Forwards to FatSecret: 
       GET /food.search.v3.1?search_expression=coke&access_token=xyz
    ↓
FatSecret API processes request (knows request is from your server IP)
    ↓
Returns results to proxy
    ↓
Proxy returns to app
    ↓
User sees food results!
```

## Key Points

- **Proxy manages OAuth** → You don't add auth to requests
- **One static IP** → Whitelist once, not per user
- **Auto token refresh** → No manual token management
- **Pass-through** → Just forwards requests + adds auth
- **Stateless** → Can run multiple instances

## Deployment Platforms

| Platform | Command | Time | Cost |
|----------|---------|------|------|
| **Railway** | `git push` (auto) | 2 min | Free |
| **Heroku** | `git push heroku main` | 3 min | $7/mo |
| **DigitalOcean** | Connect GitHub | 5 min | $5/mo |

**Recommendation**: Use Railway (easiest, free tier, auto static IP)

## Common Issues

| Issue | Fix |
|-------|-----|
| "Backend unreachable" | Check deployment platform, wait for deploy |
| "IP restricted" error | Whitelist IP on FatSecret, wait 24 hours |
| "Invalid token" | Check credentials in env vars |
| "Timeout" | Increase timeout in mobile app |

## Documentation

- **Full guide**: FATSECRET_OAUTH_PROXY_GUIDE.md
- **Complete**: FATSECRET_PROXY_COMPLETE.md
- **Setup**: FATSECRET_BACKEND_SETUP.md
- **Code**: docs/fatsecret_oauth_proxy.dart

## Next: Production Checklist

After deploying, verify:

- [ ] Server running: `curl https://your-url/health`
- [ ] Token valid: `curl https://your-url/token`
- [ ] Search works: `curl "https://your-url/food.search.v3.1?search_expression=coke"`
- [ ] IP whitelisted on FatSecret (24 hours passed)
- [ ] Mobile app configured with correct URL
- [ ] Search in app works end-to-end
- [ ] Logs show successful requests

---

**Questions?** See full documentation in FATSECRET_OAUTH_PROXY_GUIDE.md
