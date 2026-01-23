<!-- Copilot instructions for the metadash Flutter project -->
# Copilot Guidance — metadash

Purpose
- Help contributors and AI agents be productive quickly in this Flutter app.

Big picture
- Single Flutter application with platform folders for Android, iOS, macOS, Linux, Windows and Web.
- UI + app logic live under `lib/` (entry: `lib/main.dart`).
- Platform integration points live under `android/`, `ios/`, `macos/`, and `windows/` (native runners and generated plugin registrants).

Key files and patterns
- `lib/main.dart`: app entrypoint — `MyApp` (stateless) and `MyHomePage` (stateful) show common widget patterns.
- `pubspec.yaml`: dependency list and `publish_to: 'none'` (private app). Check this when adding packages.
- `analysis_options.yaml` + `flutter_lints`: follow lint rules and formatting.
- `test/widget_test.dart`: example widget test harness; keep tests under `test/`.

Developer workflows (explicit commands)
- Install deps: `flutter pub get`
- Run: `flutter run` or `flutter run -d <device-id>`
- Hot reload: save or press `r` in `flutter run` terminal; hot restart: `R`.
- Tests: `flutter test`
- Static analysis: `flutter analyze` and format: `dart format .`
- Android build locally: `flutter build apk` or `cd android && ./gradlew assembleDebug`.
- iOS: open `ios/Runner.xcworkspace` in Xcode and run `cd ios && pod install` first.

CI / recommended GitHub Actions (example)
- Workflow should: checkout, set up Flutter, `flutter pub get`, `flutter analyze`, `flutter test`.
- Only run macOS runners when iOS/macOS artifacts are required to save CI minutes.

Concrete patterns & examples
- Widget style: small, reusable UI pieces as `StatelessWidget`; screens with transient UI state as `StatefulWidget` (see `MyHomePage`).
- Avoid editing generated plugin registrants in `ios/`, `macos/`, `linux/`, `windows/` — regenerate via Flutter tooling when needed.
- Lint enforcement: fix issues from `flutter analyze` before opening PRs.

Copyable quick commands
```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
flutter build apk
cd ios && pod install
```

When to ask a human
- Native platform changes (Android permissions, iOS entitlements, signing) or CI signing keys.
- Adding packages that require manual native steps (Podfile, Gradle changes).

If you'd like, I can scaffold a GitHub Actions workflow and add a CI badge — tell me which platforms to include.
