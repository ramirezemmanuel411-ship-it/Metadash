````instructions
<!-- Copilot instructions for the metadash Flutter project -->
# Copilot Guidance — metadash

## What this app is
Metabolic dashboard: food diary, calorie/macro tracking, AI food logging, wearable health sync, and adaptive TDEE engine. Multi-platform Flutter (iOS, Android, macOS, Windows, Linux, Web).

## Architecture — big picture
- **Entry**: `lib/main.dart` → Firebase init + `.env` load → `AppShell` (bottom-nav `PageView` with tabs: Dashboard, Diary, Food Search, Exercise, Progress, Control Center).
- **Primary state**: `lib/providers/user_state.dart` — `UserState extends ChangeNotifier` holds `UserProfile`, `DailyLog`, `MetabolicSettings`, `DataInputsSettings`. Access via `Provider.of<UserState>(context)`.
- **Food search BLoC**: `lib/presentation/bloc/food_search_bloc.dart` uses `flutter_bloc` + `SearchRepository`. Everything else uses `provider`.
- **Local DB**: `lib/services/database_service.dart` — singleton SQLite via `sqflite`/`sqflite_common_ffi`. Current schema **version 13** (`metadash.db`). Bump `version` and add a case in `_onUpgrade` for every schema change.
- **Feature folders** under `lib/features/`: `dashboard`, `diary`, `food`, `food_search`, `control_center`, `profile`, `progress`, `user_selection`.

## Food search pipeline (multi-stage)
`SearchRepository` (`lib/data/repositories/search_repository.dart`) streams progressive results:
1. Local SQLite + cached results (immediate)
2. FatSecret API via Railway OAuth proxy (`https://fatsecret-proxy-production-d58c.up.railway.app`) — primary source
3. USDA / Open Food Facts as fallback

Raw results pass through `FoodSearchPipeline` (`lib/services/food_search_pipeline.dart`): normalize → score → group → deduplicate → rank (max 12). `FoodModel` is the canonical search result type; `UserFoodItem` is for user-created foods stored in SQLite.

## AI features
- `lib/services/ai_service.dart` — Groq (`llama-3.1-8b-instant`) primary, OpenAI fallback. Keys loaded from `.env`.
- `lib/services/ai_router.dart` — classifies input into 4 modes: `visionFoodEstimate`, `restaurantOrderHelper`, `mealStrategyHelper`, `structuredFoodLogger`.
- `.env` (project root, declared as a Flutter asset in `pubspec.yaml`) must contain `GROQ_API_KEY` and optionally `OPENAI_API_KEY`. Never commit real keys.

## Key conventions
- **Units**: `UserProfile.weight` in **lbs**, `height` in **inches**.
- **Models**: use `toMap()`/`fromMap()` for SQLite persistence (not `toJson`/`fromJson`).
- **Services are singletons**: use `DatabaseService()`, `HealthService()` — never construct via `._internal()`.
- **Theming**: `lib/shared/palette.dart` defines all colors. Day theme: `Palette.dayBackground` (#F6F3EC). Night: `Palette.nightBackground` (#161816). Macro colors: `Palette.macroProtein` (red), `Palette.macroCarbs` (teal), `Palette.macroFat` (orange). Always use `Palette` constants, never raw `Color(0x...)`.
- **MetabolicSettings** (Static/Adaptive/Hybrid energy model + workout accuracy) are persisted via `SharedPreferences`, not SQLite. Access via `context.read<UserState>().metabolicSettings`. See `METABOLIC_SETTINGS_IMPLEMENTATION.md` for full flow.
- **HealthService** (`lib/services/health_service.dart`) syncs HealthKit (iOS) / Health Connect (Android). Called non-blocking on app resume via `AppShell.didChangeAppLifecycleState`.

## Developer workflows
```bash
flutter pub get                        # Install deps
flutter run -d <device-id>             # Run (hot reload: r, hot restart: R)
flutter test                           # All tests
flutter test test/food_search_integration_test.dart  # Food search tests
flutter analyze && dart format .       # Lint + format (required before PRs)
flutter build apk                      # Android release
cd ios && pod install                   # iOS — run after pubspec changes or first clone
```

## External dependencies requiring care
- **FatSecret proxy** on Railway: see `deploy-railway.sh` and `lib/data/datasources/fatsecret_remote_datasource.dart`. The proxy handles OAuth 2.0; the app only talks to the proxy URL.
- **Firebase**: initialized in `main.dart`. Adding a Firebase service requires `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) updates.
- **`.env` asset**: when adding new env keys, declare the `.env` file in `pubspec.yaml` assets and read with `dotenv.env['KEY_NAME']` in the relevant service.

## When to ask a human
- Changing native permissions (iOS entitlements, Android manifest), signing config, or Firebase project settings.
- Adding packages that require Podfile/Gradle edits.
- SQLite schema migrations beyond adding columns (destructive changes to existing tables).
````
