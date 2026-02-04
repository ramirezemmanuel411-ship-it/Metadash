# FatSecret OAuth Proxy Backend

Complete OAuth 2.0 proxy server for metadash FatSecret integration.

## Quick Start

### 1. Local Development

```bash
# Get dependencies
dart pub get

# Run locally
dart run --define FATSECRET_CLIENT_ID=YOUR_ID --define FATSECRET_CLIENT_SECRET=YOUR_SECRET

# Test
curl http://localhost:8080/health
```

### 2. Deploy to Railway (Recommended - 5 minutes)

```bash
# 1. Create GitHub repo
git init
git add .
git commit -m "Initial FatSecret OAuth proxy"
git remote add origin https://github.com/YOUR_USERNAME/fatsecret-proxy.git
git push -u origin main

# 2. Go to https://railway.app
# 3. Connect GitHub repo
# 4. Set environment variables in Railway dashboard:
#    FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0
#    FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f

# 5. Deploy (automatic on git push)
git push
```

### 3. Deploy to Heroku (5 minutes)

```bash
# 1. Create Heroku app
heroku create your-app-name

# 2. Set environment variables
heroku config:set FATSECRET_CLIENT_ID=YOUR_ID
heroku config:set FATSECRET_CLIENT_SECRET=YOUR_SECRET

# 3. Deploy
git push heroku main
```

### 4. Deploy to DigitalOcean (10 minutes)

```bash
# See: docs/DEPLOY_DIGITALOCEAN.md
```

## API Endpoints

### Health Check
```bash
GET http://localhost:8080/health
```

Response:
```json
{
  "status": "ok",
  "token_valid": true,
  "expires_in": 3600
}
```

### Token Info (Debug)
```bash
GET http://localhost:8080/token
```

Response:
```json
{
  "access_token": "eyJ0eXAi...",
  "expires_in": 3600
}
```

### FatSecret Requests (Proxied)

```bash
# Search foods
GET http://localhost:8080/food.search.v3.1?search_expression=coke

# Get food nutrition
GET http://localhost:8080/food.get.v3.1?food_id=1001

# Get recipe
GET http://localhost:8080/recipe.get.v3.1?recipe_id=1001
```

## How It Works

1. **Mobile App** sends request to proxy:
   ```
   GET /food.search.v3.1?search_expression=coke
   ```

2. **Proxy Server**:
   - Checks if token is valid
   - Refreshes if needed (5 min before expiry)
   - Adds token to request
   - Forwards to FatSecret: `GET /food.search.v3.1?search_expression=coke&access_token=xyz`

3. **FatSecret API**:
   - Processes request (knows request is from your server IP)
   - Returns results

4. **Proxy Server**:
   - Returns results to mobile app

## Token Management

- **Auto-refresh**: 5 minutes before expiry
- **Caching**: In-memory token cache
- **Fallback**: Graceful error handling on token failure
- **Logging**: Detailed token lifecycle logs

## IP Whitelisting

After deployment, whitelist your proxy's IP on FatSecret:

1. Go to: https://platform.fatsecret.com/my-account/ip-restrictions
2. Add your proxy's static IP (from platform dashboard)
3. Wait up to 24 hours for activation

## Troubleshooting

### 502 Bad Gateway
**Cause**: IP not whitelisted on FatSecret
**Fix**: Add IP to FatSecret dashboard, wait 24 hours

### Token errors
**Cause**: Credentials invalid
**Fix**: Verify CLIENT_ID and CLIENT_SECRET in env vars

### Timeouts
**Cause**: Proxy slow/overloaded
**Fix**: Scale up dyno/instance, check FatSecret status

## Architecture

```
Mobile App
    ↓ HTTPS (encrypted)
OAuth Proxy
    ├─ Token Manager (auto-refresh)
    ├─ Request Forwarder
    └─ Error Handler
    ↓ HTTP (IP-whitelisted)
FatSecret API
```

## Monitoring

```bash
# Check health
curl https://your-proxy.com/health

# Check token
curl https://your-proxy.com/token

# Check logs (platform-specific)
# Railway: Dashboard → Logs
# Heroku: heroku logs --tail
# DigitalOcean: SSH → tail -f /var/log/app.log
```

## Security

- ✅ Never expose credentials in logs
- ✅ Single IP for whitelisting (controlled access)
- ✅ Token auto-refresh (no manual token management)
- ✅ CORS enabled (mobile app access)
- ✅ Error masking (no sensitive info in responses)

## Production Checklist

- [ ] Deploy to production platform
- [ ] Get static IP
- [ ] Whitelist IP on FatSecret (24h)
- [ ] Test health endpoint
- [ ] Test token endpoint
- [ ] Test search endpoint
- [ ] Monitor logs
- [ ] Set up alerts (if available)
- [ ] Document IP for ops team

## Related Documentation

- [FATSECRET_PROXY_QUICKSTART.md](../FATSECRET_PROXY_QUICKSTART.md)
- [FATSECRET_OAUTH_PROXY_GUIDE.md](../FATSECRET_OAUTH_PROXY_GUIDE.md)
- [FATSECRET_PRIMARY_DATABASE.md](../FATSECRET_PRIMARY_DATABASE.md)
