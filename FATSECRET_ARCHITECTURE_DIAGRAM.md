# FatSecret as Primary Database - Architecture Diagram

## System Architecture

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                    Flutter App (metadash)                          ┃
┃                                                                    ┃
┃  ┌────────────────────────────────────────────────────────────┐   ┃
┃  │ FastFoodSearchScreen                                       │   ┃
┃  │ (User types query, sees progressive results)              │   ┃
┃  └────────────────────────────────────────────────────────────┘   ┃
┃                           │                                        ┃
┃                           ↓                                        ┃
┃  ┌────────────────────────────────────────────────────────────┐   ┃
┃  │ FoodSearchBloc (state management + debouncing)            │   ┃
┃  │                                                            │   ┃
┃  │  Uses: SearchRepository.withFatSecret() ← NEW             │   ┃
┃  └────────────────────────────────────────────────────────────┘   ┃
┃                           │                                        ┃
┃                           ↓                                        ┃
┃  ┌────────────────────────────────────────────────────────────┐   ┃
┃  │ SearchRepository (coordinates search pipeline)            │   ┃
┃  │                                                            │   ┃
┃  │  Methods:                                                  │   ┃
┃  │  • searchFoods(query) - Main search method               │   ┃
┃  │  • withFatSecret() - Factory with FatSecret ← NEW         │   ┃
┃  └────────────────────────────────────────────────────────────┘   ┃
┃                           │                                        ┃
┃           ┌───────────────┼───────────────┐                        ┃
┃           ↓               ↓               ↓                        ┃
┃  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐              ┃
┃  │ Local DB     │ │ Cache Layer  │ │ Remote APIs  │              ┃
┃  │ (SQLite)     │ │ (SQLite)     │ │              │              ┃
┃  │              │ │              │ │ ├─ FatSecret │ ← PRIMARY   ┃
┃  │ (Fast)       │ │ (Very Fast)  │ │ ├─ USDA      │ ← FALLBACK  ┃
┃  │              │ │              │ │ └─ OpenFood  │ ← FALLBACK  ┃
┃  └──────────────┘ └──────────────┘ └──────────────┘              ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
                           │
                           │ HTTPS (encrypted)
                           ↓
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                      OAuth Proxy Server                             ┃
┃                  (Your deployed backend)                            ┃
┃                                                                    ┃
┃  ┌────────────────────────────────────────────────────────────┐   ┃
┃  │ Token Manager                                              │   ┃
┃  │ • Manages OAuth 2.0 tokens                                │   ┃
┃  │ • Auto-refreshes before expiry                            │   ┃
┃  │ • Caches tokens in memory                                 │   ┃
┃  └────────────────────────────────────────────────────────────┘   ┃
┃                                                                    ┃
┃  ┌────────────────────────────────────────────────────────────┐   ┃
┃  │ Request Handler                                            │   ┃
┃  │ • Intercepts requests                                     │   ┃
┃  │ • Adds access token to requests                           │   ┃
┃  │ • Forwards to FatSecret / USDA / OpenFood                │   ┃
┃  │ • Returns responses to app                                │   ┃
┃  └────────────────────────────────────────────────────────────┘   ┃
┃                                                                    ┃
┃  Static IP: 1.2.3.4 (whitelisted on FatSecret)                   ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    │                   │                      │
    │ HTTP (IP-only)    │ HTTP (IP-only)      │ HTTP (IP-only)
    ↓                   ↓                      ↓
 ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
 │ FatSecret    │  │ USDA API     │  │ OpenFoodFacts    │
 │ API          │  │              │  │ API              │
 │              │  │ (if fallback) │  │ (if fallback)    │
 └──────────────┘  └──────────────┘  └──────────────────┘
```

## Search Flow Diagram

```
USER ENTERS QUERY: "coke"
        │
        ├─ Query: "coke"
        │ Lowercase: "coke"
        │ Min length: 2 chars ✓
        │
        ↓
┌─────────────────────────────────────────────────────────┐
│ STAGE 1: Local SQLite Search                            │
│ Time: 15-50ms                                           │
│                                                         │
│ SELECT * FROM foods WHERE name LIKE '%coke%'           │
│ Already in our database from previous searches          │
│                                                         │
│ Results: [Coca Cola Original, Coca Cola Zero, ...]     │
│                                                         │
│ ✓ Found → Show to user immediately                     │
│ ✗ Not found → Continue                                 │
└─────────────────────────────────────────────────────────┘
        │
        ├─ Has results? YES
        │ Dedup & normalize
        │ Emit: SearchSuccess(source: local)
        │
        ├─ Has results? NO → Continue
        │
        ↓
┌─────────────────────────────────────────────────────────┐
│ STAGE 2: Cache Check (24-hour TTL)                      │
│ Time: 5-20ms (if cached)                                │
│                                                         │
│ SELECT * FROM search_cache WHERE query='coke'          │
│ AND timestamp > now - 24 hours                          │
│                                                         │
│ Cache hit? Return cached results                        │
│ Cache miss? Continue to fresh fetch                     │
│                                                         │
│ ✓ Valid cache → Show to user                           │
│ ✗ Expired or missing → Continue                        │
└─────────────────────────────────────────────────────────┘
        │
        ├─ Has valid cache? YES
        │ Emit: SearchSuccess(source: cache)
        │ Still fetch fresh in background
        │
        ├─ Has valid cache? NO → Continue
        │
        ↓
┌─────────────────────────────────────────────────────────┐
│ STAGE 3: PRIMARY - FatSecret API                        │
│ Time: 500-2000ms                                        │
│                                                         │
│ POST https://proxy.railway.app/food.search.v3.1        │
│ Parameters:                                             │
│   search_expression: "coke"                             │
│   access_token: [auto-managed by proxy]                 │
│                                                         │
│ Proxy:                                                  │
│ 1. Checks if token valid                                │
│ 2. Refreshes if within 5 mins of expiry                 │
│ 3. Adds token to request                                │
│ 4. Forwards to FatSecret: "GET /food.search ..."       │
│ 5. Returns results to app                               │
│                                                         │
│ Results: [                                              │
│   {id: 1001, name: 'Coca Cola', cal: 140},             │
│   {id: 1002, name: 'Coca Cola Zero', cal: 0},          │
│   ...                                                   │
│ ]                                                       │
│                                                         │
│ ✓ Got results → Use FatSecret data                      │
│ ✗ Empty or error → Fallback                             │
└─────────────────────────────────────────────────────────┘
        │
        ├─ FatSecret has results? YES ✓
        │ Parse to FoodModel
        │ Save to local DB (for future searches)
        │ Cache results (24-hour TTL)
        │ Emit: SearchSuccess(source: remote)
        │ → SKIP FALLBACK, Return to user
        │
        ├─ FatSecret empty? NO RESULTS
        │ Log: "FatSecret returned 0 results"
        │ → Continue to fallback
        │
        ├─ FatSecret failed? TIMEOUT/ERROR
        │ Log: "FatSecret error: timeout"
        │ → Continue to fallback
        │
        ↓
┌─────────────────────────────────────────────────────────┐
│ STAGE 4: FALLBACK - USDA + OpenFoodFacts                │
│ Time: 1000-3000ms                                       │
│ Only runs if FatSecret is empty or failed               │
│                                                         │
│ POST https://usda-api.com/foods/search               │
│ POST https://world.openfoodfacts.org/cgi/search.pl   │
│                                                         │
│ Results: [                                              │
│   {id: 'usda_001', name: 'Beverages, soft drinks'},   │
│   {id: 'off_001', name: 'Coke Classic'},               │
│   ...                                                   │
│ ]                                                       │
│                                                         │
│ ✓ Got fallback results → Use them                      │
│ ✗ Fallback also empty → Return local cache             │
└─────────────────────────────────────────────────────────┘
        │
        ├─ Fallback has results? YES
        │ Parse to FoodModel
        │ Merge with local results
        │ Deduplicate
        │ Emit: SearchSuccess(source: remote)
        │ Return to user
        │
        ├─ Fallback empty? NO RESULTS
        │ Emit: SearchEmpty(query: 'coke')
        │ Show "No results found" message
        │
        ├─ Fallback failed? ERROR
        │ Emit: SearchError(message: 'Network error')
        │ Show offline results
        │
        ↓
USER SEES RESULTS IN APP
        │
        ├─ From FatSecret (primary)
        │ OR
        ├─ From USDA/OpenFoodFacts (fallback)
        │ OR
        ├─ From Local Cache (offline)
        │ OR
        └─ "No results" message
```

## Code Execution Timeline

```
t=0ms    User types "coke" and hits search
         │
         ├─ Query validation & normalization
         │
t=5ms    ├─ Start local DB search (async)
         │ SearchRepository.searchFoods("coke")
         │
t=20-50ms├─ Local results ready
         │ Emit SearchSuccess(source: local)
         │ UI shows loading skeleton + local items
         │
t=50ms   ├─ Check cache (if not force refresh)
         │ getCachedSearch(cacheKey)
         │
t=60ms   ├─ Emit cache results if valid
         │ Emit SearchSuccess(source: cache)
         │ UI updates with better results
         │
t=100ms  ├─ Start FatSecret fetch
         │ await _fatSecretDatasource.searchFoods()
         │
t=1200ms ├─ FatSecret response arrives
         │ Parse: FatSecretRemoteDatasource.parseFoodsFromSearch()
         │ 
         │ If results exist:
         │   ├─ Save to local DB
         │   ├─ Cache for 24h
         │   ├─ Dedup against local
         │   ├─ Emit SearchSuccess
         │   └─ UI updates with FatSecret results
         │
         │ If empty:
         │   └─ Continue to fallback
         │
t=1250ms ├─ Start fallback fetch (only if empty)
         │ await _remoteDatasource.searchBoth()
         │
t=4000ms ├─ Fallback response arrives
         │ Merge + dedup + emit
         │ UI updates with USDA/OFF results
         │
t=4100ms └─ User sees final results

Timeline depends on network:
- Fast connection: 1-2 seconds (FatSecret only)
- Slow connection: 3-5 seconds (FatSecret + fallback)
- Offline: <100ms (cached/local only)
```

## Data Flow During Search

```
app/search.dart
        │ query: "coke"
        ↓
repository.searchFoods("coke")
        │
        ├─ Step 1: Local Search
        │   datasource.searchFoodsLocal("coke")
        │   └─ SQLite full-text search
        │   └─ Returns: List<FoodModel>
        │
        ├─ Step 2: Prepare results (dedup, normalize)
        │   FoodDedupsService.deduplicate()
        │   CanonicalFoodService.processSearchResults()
        │   └─ Returns: List<FoodModel> (cleaned)
        │
        ├─ Step 3: Emit local results
        │   yield SearchResult(
        │     results: [food1, food2, ...],
        │     source: SearchSource.local,
        │     isComplete: false,
        │   )
        │   └─ UI receives & shows skeleton loader
        │
        ├─ Step 4: FatSecret fetch
        │   await _fatSecretDatasource.searchFoods("coke")
        │   └─ HTTP GET /food.search.v3.1?search_expression=coke
        │   └─ Proxy adds OAuth token
        │   └─ Returns: Map<String, dynamic> (raw JSON)
        │
        ├─ Step 5: Parse FatSecret
        │   FatSecretRemoteDatasource.parseFoodsFromSearch(rawData)
        │   └─ Converts: Map → List<FoodModel>
        │   └─ Extracts: id, name, calories, nutrition, etc.
        │   └─ Returns: List<FoodModel>
        │
        ├─ Step 6: Merge & deduplicate
        │   _mergeResults(local, fatsecret)
        │   deduplicateFoods(merged)
        │   CanonicalFoodService.processSearchResults()
        │   └─ Returns: List<FoodModel> (final)
        │
        ├─ Step 7: Save for future
        │   _localDatasource.saveFoodsBatch(results)
        │   cacheSearchResults(SearchCacheEntry)
        │   └─ For instant results next time
        │
        └─ Step 8: Emit final results
            yield SearchResult(
              results: [food1, food2, ...],
              source: SearchSource.remote,
              isComplete: true,
            )
            └─ UI updates with FatSecret results

bloc/food_search_bloc.dart
        │ receives SearchResult events
        ↓
        emit(FoodSearchState) for each stage
        │
        ├─ Stage 1: SearchLoading(query: "coke")
        ├─ Stage 2: SearchSuccess(results from local)
        ├─ Stage 3: SearchSuccess(results from FatSecret)
        └─ Stage 4: SearchSuccess(isComplete: true)

screens/fast_food_search_screen.dart
        │ listens to FoodSearchBloc
        ↓
        ├─ SearchLoading? Show skeleton loader
        ├─ SearchSuccess? Show results
        │   ├─ Local source: "Searching..." indicator
        │   ├─ Cache source: "Found in cache"
        │   └─ Remote source: Show results + source badge
        ├─ SearchEmpty? "No results found"
        └─ SearchError? "Network error"

        └─ User taps result
           │
           └─ Navigator.pop(foodModel)
              └─ Returns to diary screen
```

## Priority / Preference Matrix

```
┌──────────────────────────────────────────────────────────────┐
│ Database Priority (Left = Higher Priority)                   │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ Scenario 1: All sources have results                         │
│ ┌────────────────────────────────────────────────────────┐  │
│ │ Local → Cache → FatSecret ✓ USE FatSecret             │  │
│ │                                                        │  │
│ │ Reason: Highest quality nutrition data                │  │
│ └────────────────────────────────────────────────────────┘  │
│                                                              │
│ Scenario 2: FatSecret empty, but USDA has results           │
│ ┌────────────────────────────────────────────────────────┐  │
│ │ Local → Cache → FatSecret ✗ → USDA ✓ USE USDA        │  │
│ │                                                        │  │
│ │ Reason: FatSecret empty, fallback works               │  │
│ └────────────────────────────────────────────────────────┘  │
│                                                              │
│ Scenario 3: FatSecret timeout, USDA works                   │
│ ┌────────────────────────────────────────────────────────┐  │
│ │ Local → Cache → FatSecret ✗ timeout                   │  │
│ │         → USDA ✓ USE USDA (automatic fallback)       │  │
│ │                                                        │  │
│ │ Reason: Automatic retry with fallback                 │  │
│ └────────────────────────────────────────────────────────┘  │
│                                                              │
│ Scenario 4: All APIs fail                                   │
│ ┌────────────────────────────────────────────────────────┐  │
│ │ Local ✓ → Cache ✓ → (both APIs fail) ✗                │  │
│ │                                                        │  │
│ │ USE: Local + Cache                                    │  │
│ │ Show: "Offline mode - showing cached results"         │  │
│ │ Reason: Better to show old data than nothing          │  │
│ └────────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## File Structure

```
lib/
├── presentation/
│   ├── bloc/
│   │   └── food_search_bloc.dart ← Uses SearchRepository.withFatSecret()
│   └── screens/
│       └── fast_food_search_screen.dart ← UI that shows progressive results
│
├── data/
│   ├── repositories/
│   │   └── search_repository.dart ← MAIN: Controls search pipeline
│   │       • searchFoods(query) - Main search method
│   │       • withFatSecret() - NEW factory method ← You are here
│   │       • Stage 1: Local search
│   │       • Stage 2: Cache check
│   │       • Stage 3: FatSecret (PRIMARY) ← NEW
│   │       • Stage 4: USDA/OFF (FALLBACK) ← NEW
│   │       • Merge & deduplicate
│   │
│   └── datasources/
│       ├── food_local_datasource.dart
│       │   └── searchFoodsLocal(query)
│       │
│       ├── food_remote_datasource.dart
│       │   └── searchBoth(query) - USDA + OpenFoodFacts
│       │
│       └── fatsecret_remote_datasource.dart ← NEW PRIMARY
│           ├── searchFoods(query) - Call proxy
│           ├── parseFoodsFromSearch(json) - Parse response
│           └── Communicates with OAuth proxy
│
└── services/
    ├── food_dedup_service.dart
    │   └── deduplicateFoods() - Remove duplicates
    │
    ├── canonical_food_service.dart
    │   └── processSearchResults() - Group similar items
    │
    └── food_display_normalizer.dart
        └── Normalize display titles/subtitles
```

---

**Ready to deploy? See FATSECRET_PROXY_QUICKSTART.md for 5-minute setup.** ✅
