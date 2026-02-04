# FatSecret Deployment Checklist

## Pre-Deployment ✅

- [x] Created mobile app components (datasource, repository, client)
- [x] Created backend proxy server (production-ready)
- [x] Secure credential storage (.env file)
- [x] Complete documentation
- [x] Code examples
- [x] Zero compilation errors

## Deployment Checklist

### Phase 1: Deploy Backend Server

- [ ] **Choose Platform**
  - [ ] Railway (Recommended - Easiest)
  - [ ] Heroku (Traditional but free tier ending)
  - [ ] DigitalOcean ($5/month - Most reliable)

- [ ] **Get Credentials Ready**
  - [ ] Client ID: `b9f7e7de97b340b7915c3ac9bab9bfe0`
  - [ ] Client Secret: `b788a80bfaaf4e569e811a381be3865f`

- [ ] **Deploy to Chosen Platform**
  - [ ] If Railway: Follow Railway docs (push to GitHub, auto-deploy)
  - [ ] If Heroku: `heroku create`, set config vars, `git push heroku main`
  - [ ] If DigitalOcean: Create App, connect GitHub, set vars, deploy

- [ ] **Verify Deployment**
  - [ ] Access backend health endpoint: `GET /health`
  - [ ] Check response: `{"status": "ok", ...}`

### Phase 2: Get Static IP

- [ ] **Find Your Backend Server's IP**
  - [ ] Railway: Dashboard → Settings → Public URL / IP
  - [ ] Heroku: Need paid add-on for static IP
  - [ ] DigitalOcean: Dashboard → Networking → Static IPs
  - [ ] Note the IP: `___.___.___.__`

- [ ] **Document Backend URL**
  - [ ] Backend URL: `https://_______________`
  - [ ] Backend IP: `___.___.___.__`

### Phase 3: Whitelist IP on FatSecret

- [ ] **Go to FatSecret IP Restrictions**
  - [ ] URL: https://platform.fatsecret.com/my-account/ip-restrictions
  - [ ] Sign in with: ramirezemmanueld411@gmail.com

- [ ] **Add IP Address**
  - [ ] Click "Add IP Address"
  - [ ] Paste your backend server IP
  - [ ] Click Save
  - [ ] Note: Changes may take up to 24 hours

- [ ] **Verify Whitelist**
  - [ ] Wait a few hours
  - [ ] Test from backend: `curl https://platform.fatsecret.com/rest/health`

### Phase 4: Configure Mobile App

- [ ] **Update Backend URL in Code**
  ```dart
  const backendUrl = 'https://your-backend-url-here.com';
  ```
  - [ ] Copy actual URL from deployment platform
  - [ ] Test that it's accessible from browser

- [ ] **Initialize FatSecret in main.dart**
  ```dart
  final fatsecretDatasource = FatSecretRemoteDatasource(
    backendUrl: backendUrl,
  );
  final fatsecretRepository = FatSecretRepository(
    remoteDatasource: fatsecretDatasource,
  );
  ```

- [ ] **Update SearchRepository** (Optional - for integrated search)
  - [ ] Pass fatsecretDatasource to SearchRepository constructor
  - [ ] Update search to include FatSecret results

### Phase 5: Test on Device

- [ ] **Run App**
  ```bash
  flutter run
  ```

- [ ] **Test Endpoints**
  - [ ] Search for "Coke"
  - [ ] Search for "Pizza Hut"
  - [ ] Search for "Salad"
  - [ ] Search for "Water"

- [ ] **Verify Results**
  - [ ] Results appear without "IP restricted" error
  - [ ] Results include FatSecret data
  - [ ] No duplicates (deduplication working)
  - [ ] Nutrition info present

- [ ] **Check Logs**
  - [ ] Backend logs show successful requests
  - [ ] No OAuth errors
  - [ ] No timeout errors

### Phase 6: Production Monitoring

- [ ] **Set Up Logging**
  - [ ] Monitor backend for errors
  - [ ] Track API quota usage
  - [ ] Alert on failures

- [ ] **Performance Optimization**
  - [ ] Enable local caching
  - [ ] Add result pagination
  - [ ] Monitor response times

- [ ] **Maintenance**
  - [ ] Check token refresh is working
  - [ ] Verify IP whitelist still active
  - [ ] Update credentials if compromised
  - [ ] Monitor FatSecret API changes

## Troubleshooting

### "Backend unreachable"
```bash
# Test backend health
curl https://your-backend-url/health

# If failed:
1. Check backend is running on deployment platform
2. Check URL is correct
3. Check internet connection
4. Wait for deployment to complete
```

### "IP restricted" error
```bash
# Wait 24 hours after whitelisting IP
# Then test:
curl -H "Authorization: OAuth oauth_consumer_key=YOUR_CLIENT_ID" \
  "https://platform.fatsecret.com/rest/food.search.v3.1?search_expression=coke"

# If still failing:
1. Verify IP is correct on FatSecret dashboard
2. Ask FatSecret support to force sync
3. Try different IP if available
```

### "Invalid credentials"
```bash
# Verify credentials:
echo $FATSECRET_CLIENT_ID
echo $FATSECRET_CLIENT_SECRET

# If wrong:
1. Go to FatSecret Developer Console
2. Get fresh credentials
3. Update environment variables
4. Restart backend server
```

### "Timeout or slow responses"
```bash
# Check backend logs for:
1. OAuth token requests taking too long
2. FatSecret API being slow
3. Network latency

# Solutions:
1. Increase timeout in datasource
2. Add request caching
3. Use CDN or edge computing
```

## Success Indicators

✅ All checks passed when:

- [ ] Health endpoint returns `{"status": "ok"}`
- [ ] Search returns results without errors
- [ ] Results include FatSecret data alongside USDA/OFF
- [ ] No "IP restricted" or "Unauthorized" errors
- [ ] Deduplication working (no duplicate items)
- [ ] Nutrition data complete
- [ ] App responsive (< 2s search time)
- [ ] Logs show successful API calls
- [ ] Backend running stable for 24+ hours

## Documentation References

| Document | Purpose |
|----------|---------|
| `FATSECRET_SETUP.md` | Credential configuration |
| `FATSECRET_BACKEND_SETUP.md` | Detailed deployment instructions |
| `FATSECRET_INTEGRATION_COMPLETE.md` | Full integration guide |
| `FATSECRET_READY_TO_DEPLOY.md` | Quick start (this file) |
| `lib/example_fatsecret_integration.dart` | Code examples |
| `docs/fatsecret_backend_deployable.dart` | Server source code |

## Quick Commands

```bash
# Test backend health
curl https://your-backend-url/health

# Search foods
curl "https://your-backend-url/api/foods/search?q=coke"

# Check logs (Platform dependent)
heroku logs -t                    # Heroku
railway logs                       # Railway
# DigitalOcean: Check in dashboard

# Restart backend
heroku restart                     # Heroku
# Railway/DigitalOcean: Redeploy from dashboard
```

## Estimated Timeline

| Phase | Time | Notes |
|-------|------|-------|
| Deploy Backend | 5-30 min | Depends on platform |
| Get Static IP | 0-5 min | Visible immediately |
| Whitelist IP | 0-24 hours | May take up to 24 hours |
| Update Mobile App | 5-10 min | Just change URL |
| Test on Device | 10-20 min | Comprehensive testing |
| **Total** | **~1-2 hours** | Most time is waiting for IP whitelist |

## Post-Launch

- [ ] Monitor backend for 24 hours
- [ ] Track API usage
- [ ] Gather user feedback
- [ ] Optimize slow queries
- [ ] Plan for scaling if needed
- [ ] Update documentation with lessons learned

---

**Status**: Ready to Deploy! 🚀

Next Step: Choose platform → Deploy backend → Whitelist IP → Test
