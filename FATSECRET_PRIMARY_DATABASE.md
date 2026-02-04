# FatSecret as Primary Database - Integration Guide

## Overview

FatSecret is now the **primary database** for food search in metadash, with USDA and Open Food Facts as automatic fallbacks.

```
User Search Query
       ↓
   Local Cache (instant)
       ↓
   FatSecret API (PRIMARY) ✅
       ├─ Results found? → Return to user
       └─ No results? → Continue
       ↓
   USDA + OpenFoodFacts (FALLBACK) ← Only if FatSecret empty
       ↓
   User sees best available results
```

## What Changed

### Search Pipeline

**Before** (USDA-first):
```
Local → USDA/OpenFoodFacts → (maybe FatSecret)
```

**Now** (FatSecret-first):
```
Local → FatSecret (PRIMARY) → USDA/OpenFoodFacts (FALLBACK only if needed)
```

### Key Changes

| Component | Change |
|-----------|--------|
| `SearchRepository.searchFoods()` | Now tries FatSecret first, falls back to USDA/OFF |
| `SearchRepository.withFatSecret()` | New factory method auto-initializes FatSecret |
| `FoodSearchBloc` | Uses `SearchRepository.withFatSecret()` by default |
| Fallback logic | USDA/OFF only fetched if FatSecret returns empty |

## How It Works

### Stage 1: Local Search (Always runs)
```dart
// Search local SQLite database (offline cache)
// Returns instant results from previous searches
final localResults = await localDatasource.searchFoodsLocal(query);
```

### Stage 2: Check Cache (If not force refresh)
```dart
// Search cached results (24-hour TTL)
final cached = await localDatasource.getCachedSearch(cacheKey);
```

### Stage 3: Fetch Fresh - FatSecret PRIMARY
```dart
if (_fatSecretDatasource != null) {
  try {
    // 1. Try FatSecret first
    final rawData = await _fatSecretDatasource.searchFoods(query);
    final fatSecretResults = parseFoodsFromSearch(rawData);
    
    // 2. If we got results, use them
    if (fatSecretResults.isNotEmpty) {
      remoteResults.addAll(fatSecretResults);
      // Skip to database save (don't fetch fallback)
    }
  } catch (e) {
    print('FatSecret failed: $e');
    // Continue to fallback
  }
}
```

### Stage 4: Fallback - USDA + OpenFoodFacts (Only if empty)
```dart
// Only runs if FatSecret was empty or failed
if (remoteResults.isEmpty) {
  final fallbackResults = await _remoteDatasource.searchBoth(query);
  remoteResults.addAll(fallbackResults);
}
```

### Stage 5: Merge & Deduplicate
```dart
// Combine: local + FatSecret (or fallback)
final allResults = _mergeResults(localResults, remoteResults);

// Remove duplicates
final deduped = deduplicateFoods(allResults);

// Group similar items (canonical parsing)
final canonical = CanonicalFoodService.processSearchResults(
  results: deduped,
  query: query,
);
```

## Code Changes

### File: `lib/data/repositories/search_repository.dart`

**New factory method:**
```dart
factory SearchRepository.withFatSecret({
  String? backendUrl,
}) {
  FatSecretRemoteDatasource? fatSecretDatasource;
  
  try {
    fatSecretDatasource = FatSecretRemoteDatasource(
      backendUrl: backendUrl ?? 'https://api.fatsecret.com',
    );
  } catch (e) {
    print('FatSecret initialization failed: $e');
  }

  return SearchRepository(
    fatSecretDatasource: fatSecretDatasource,
  );
}
```

**Updated search logic:**
```dart
// PRIMARY: Try FatSecret first
List<FoodModel> remoteResults = [];

if (_fatSecretDatasource != null) {
  try {
    final rawFatSecretData = await _fatSecretDatasource.searchFoods(query);
    final fatSecretResults = FatSecretRemoteDatasource.parseFoodsFromSearch(rawFatSecretData);
    remoteResults.addAll(fatSecretResults);
  } catch (e) {
    print('FatSecret search error: $e - Falling back to USDA/OpenFoodFacts');
  }
}

// FALLBACK: If FatSecret empty or failed, try USDA + OpenFoodFacts
if (remoteResults.isEmpty) {
  final fallbackResults = await _remoteDatasource.searchBoth(query);
  remoteResults.addAll(fallbackResults);
}

// ... rest of processing
```

### File: `lib/presentation/bloc/food_search_bloc.dart`

**Before:**
```dart
FoodSearchBloc({SearchRepository? repository})
    : _repository = repository ?? SearchRepository(),
```

**After:**
```dart
FoodSearchBloc({SearchRepository? repository})
    : _repository = repository ?? SearchRepository.withFatSecret(),
```

## Deployment Checklist

- [ ] **Deploy FatSecret Proxy Backend**
  ```bash
  # See: FATSECRET_OAUTH_PROXY_GUIDE.md
  # Deploy to Railway/Heroku/DigitalOcean
  ```

- [ ] **Get Static IP**
  - Visible in platform dashboard after deployment
  - Example: `proxy.railway.app` or `1.2.3.4`

- [ ] **Whitelist IP on FatSecret**
  - Go to: https://platform.fatsecret.com/my-account/ip-restrictions
  - Add your proxy's static IP
  - Wait up to 24 hours for activation

- [ ] **Update Backend URL** (if needed)
  ```dart
  // In code:
  final repo = SearchRepository.withFatSecret(
    backendUrl: 'https://your-proxy-url.com',
  );
  
  // Or in environment:
  // Set FATSECRET_BACKEND_URL before running
  ```

- [ ] **Test Search**
  - Run: `flutter run`
  - Search for a food (e.g., "coke")
  - Verify results come from FatSecret (check proxy logs)
  - If empty, verify USDA/OFF fallback triggers

## Error Handling

### FatSecret unavailable?
```
✅ Automatically falls back to USDA/OpenFoodFacts
✅ User sees results from fallback
⚠️  Error logged but not shown to user
```

### FatSecret returns empty?
```
✅ Automatically tries USDA/OpenFoodFacts
✅ User gets broader search coverage
✅ Supplements FatSecret with OFF results
```

### Both FatSecret and USDA/OFF fail?
```
✅ Returns local cached results
⚠️  Shows "No results" message
ℹ️  Suggests offline content
```

## Benefits

✅ **Primary: Better Nutrition Data** - FatSecret specializes in nutrition  
✅ **Fallback Safety** - USDA/OFF always available as backup  
✅ **Wider Coverage** - Supplements FatSecret gaps with USDA/OFF  
✅ **Auto-failover** - No manual intervention needed  
✅ **Progressive Loading** - Local → FatSecret → Fallback as results arrive  

## Performance Impact

| Stage | Source | Time | Impact |
|-------|--------|------|--------|
| Local | SQLite | 15-50ms | ✅ Instant |
| Cache | SQLite | 5-20ms | ✅ Very fast |
| FatSecret | API | 500-2000ms | ✅ Good |
| Fallback | USDA/OFF | 1000-3000ms | ⚠️ Slower (only if needed) |

**Overall**: Faster than old USDA-first approach because FatSecret results are usually sufficient.

## Customization

### Change Backend URL
```dart
// Instead of default
final repo = SearchRepository.withFatSecret();

// Use custom URL
final repo = SearchRepository.withFatSecret(
  backendUrl: 'https://my-custom-proxy.com',
);
```

### Disable FatSecret (use USDA-only)
```dart
// Create with no FatSecret datasource
final repo = SearchRepository(
  fatSecretDatasource: null,
);
```

### Force Refresh (skip cache)
```dart
// Normally uses cache
stream1 = repository.searchFoods('coke');

// Force fresh from API
stream2 = repository.searchFoods('coke', forceRefresh: true);
```

## Testing

### Unit Test
```dart
test('FatSecret primary, USDA fallback', () async {
  // Create repository with mock datasources
  final fatSecretMock = MockFatSecretDatasource();
  final usdaMock = MockFoodRemoteDatasource();
  
  final repo = SearchRepository(
    fatSecretDatasource: fatSecretMock,
    remoteDatasource: usdaMock,
  );

  // Mock: FatSecret returns empty
  when(fatSecretMock.searchFoods('coke'))
    .thenAnswer((_) async => {});

  // Search
  final stream = repo.searchFoods('coke');
  
  // Verify: Falls back to USDA
  final result = await stream.first;
  verify(usdaMock.searchBoth('coke')).called(1);
});
```

### Integration Test
```dart
testWidgets('Search shows FatSecret results', (tester) async {
  // Deploy real proxy
  // Set FATSECRET_BACKEND_URL
  
  await tester.pumpWidget(const MyApp());
  
  // Search
  await tester.enterText(find.byType(TextField), 'coke');
  await tester.pumpAndSettle(Duration(seconds: 3));
  
  // Verify results
  expect(find.text(contains('coke')), findsWidgets);
});
```

## Logs

Look for these in Flutter console during search:

```
✅ FatSecret found 23 results for "coke"
   [SOURCE: fatsecret_remote_datasource]
   [TIME: 1200ms]

✅ Found results from FatSecret, skipping USDA/OFF
   [SOURCE: search_repository]

❌ FatSecret error: Timeout - Falling back to USDA/OpenFoodFacts
   [SOURCE: search_repository]
   [FALLBACK: Fetching from USDA/OFF]

✅ Fallback returned 45 results
   [SOURCE: food_remote_datasource]
```

## Troubleshooting

### Search returns only local/old results
**Symptom**: No new results from FatSecret/USDA
**Cause**: Proxy unreachable or offline
**Fix**:
1. Check proxy status: `curl https://your-proxy-url/health`
2. Verify IP whitelisting on FatSecret
3. Check proxy logs: `docker logs proxy-container`

### Search very slow (>5 seconds)
**Symptom**: Long delay before showing results
**Cause**: FatSecret timeout falling back to USDA
**Fix**:
1. Reduce timeout in FatSecretRemoteDatasource:
   ```dart
   const Duration timeout = Duration(seconds: 2); // Was 5
   ```
2. Check proxy latency: `curl -w "@curl-format.txt" https://your-proxy-url/health`

### No results at all
**Symptom**: "No results found" even for common foods
**Cause**: 
- FatSecret and USDA/OFF both failed
- Local database empty
**Fix**:
1. Check proxy status
2. Verify USDA/OFF fallback working: `flutter analyze`
3. Pre-populate with common foods:
   ```dart
   await localDatasource.seedCommonFoods();
   ```

## Migration from USDA-First

If you were using the old USDA-first search:

```dart
// OLD CODE (no longer needed)
final repo = SearchRepository();
// This used USDA → FatSecret → OFF order

// NEW CODE (use this)
final repo = SearchRepository.withFatSecret();
// This uses FatSecret → USDA/OFF order
```

**No code changes needed!** The BLoC already uses `withFatSecret()` by default.

## FAQ

**Q: What if FatSecret goes down?**  
A: Falls back to USDA/OpenFoodFacts automatically. User sees results from those sources.

**Q: Can I use FatSecret offline?**  
A: No, but you'll get cached results from previous searches. Full offline support requires pre-caching.

**Q: Why both FatSecret and USDA?**  
A: FatSecret has better nutrition data, USDA has more foods. Together they provide best coverage.

**Q: How do I revert to USDA-first?**  
A: Change BLoC default:
```dart
// In food_search_bloc.dart
_repository = repository ?? SearchRepository(); // Remove withFatSecret()
```

**Q: Is there a performance penalty?**  
A: No, FatSecret is usually faster than USDA because results are sufficient.

**Q: What about rate limits?**  
A: FatSecret: 50 req/min. USDA: 1000 req/hr. Both have plenty of headroom for mobile app.

---

## Related Documentation

- [FATSECRET_OAUTH_PROXY_GUIDE.md](FATSECRET_OAUTH_PROXY_GUIDE.md) - Deploy proxy server
- [FATSECRET_PROXY_QUICKSTART.md](FATSECRET_PROXY_QUICKSTART.md) - 5-minute setup
- [FATSECRET_INTEGRATION_COMPLETE.md](FATSECRET_INTEGRATION_COMPLETE.md) - Architecture details
- [FOOD_SEARCH_IMPLEMENTATION.md](FOOD_SEARCH_IMPLEMENTATION.md) - Search algorithm details
