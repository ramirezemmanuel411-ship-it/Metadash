# FatSecret API Integration Setup

## 1. Secure Credential Storage

Your FatSecret API credentials have been generated. Follow these steps to securely integrate them:

### Option A: Local Development (.env file)

**⚠️ IMPORTANT**: `.env` is listed in `.gitignore` and will NOT be committed to git.

1. Create a `.env` file in the project root (same level as `pubspec.yaml`):
   ```bash
   touch .env
   ```

2. Add your credentials (replace with actual values):
   ```
   FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0
   FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
   ```

3. **Never commit this file** - it's protected by `.gitignore`

### Option B: Environment Variables (Recommended for CI/CD)

For GitHub Actions or other CI/CD systems, pass credentials via command line:

```bash
flutter run \
  --dart-define=FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0 \
  --dart-define=FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f
```

Or in GitHub Actions:
```yaml
- name: Run Flutter tests
  env:
    FATSECRET_CLIENT_ID: ${{ secrets.FATSECRET_CLIENT_ID }}
    FATSECRET_CLIENT_SECRET: ${{ secrets.FATSECRET_CLIENT_SECRET }}
  run: |
    flutter run \
      --dart-define=FATSECRET_CLIENT_ID=$FATSECRET_CLIENT_ID \
      --dart-define=FATSECRET_CLIENT_SECRET=$FATSECRET_CLIENT_SECRET
```

### Option C: Platform-Specific Secure Storage (Production)

For production apps, use platform-specific secure storage:

**iOS (Keychain)**:
```dart
import 'flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage();
final clientId = await storage.read(key: 'fatsecret_client_id');
final clientSecret = await storage.read(key: 'fatsecret_client_secret');
```

**Android (Android Keystore)**:
Same as iOS with `flutter_secure_storage` package.

## 2. Configuration File

The configuration is managed by:
- **File**: `lib/config/fatsecret_config.dart`
- **Class**: `FatSecretConfig`
- **Methods**:
  - `clientId`: Loads from `String.fromEnvironment('FATSECRET_CLIENT_ID')`
  - `clientSecret`: Loads from `String.fromEnvironment('FATSECRET_CLIENT_SECRET')`
  - `getAuthHeaders()`: Returns authorization headers for API calls
  - `isConfigured()`: Checks if credentials are set

## 3. Usage in Code

```dart
import 'package:metadash/config/fatsecret_config.dart';

// Access credentials
final clientId = FatSecretConfig.clientId;
final clientSecret = FatSecretConfig.clientSecret;

// Get auth headers
final headers = FatSecretConfig.getAuthHeaders();

// Check if configured
if (FatSecretConfig.isConfigured()) {
  // Proceed with API calls
} else {
  // Show error: credentials not configured
}
```

## 4. Security Best Practices

✅ **DO**:
- Store credentials in `.env` file (not committed)
- Use environment variables for CI/CD
- Use platform-specific secure storage for production
- Rotate credentials if exposed
- Use OAuth2 flow (not API key) for requests

❌ **DON'T**:
- Commit `.env` file to git
- Hardcode credentials in source code
- Share credentials in Slack/email/chat
- Use old credentials if compromised
- Store plain text in app bundles

## 5. Credential Rotation

If you ever expose these credentials:
1. Go to FatSecret Developer Console
2. Revoke current credentials
3. Generate new ones
4. Update `.env` and redeploy

## 6. CI/CD Setup

Add secrets to GitHub (Settings → Secrets and variables → Actions):
1. `FATSECRET_CLIENT_ID`
2. `FATSECRET_CLIENT_SECRET`

Then use in workflows as shown in Option B.

## 7. Testing

To verify credentials are loaded correctly:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!FatSecretConfig.isConfigured()) {
    throw Exception('FatSecret credentials not configured');
  }
  
  print('✅ FatSecret configured');
  print('Client ID loaded: ${FatSecretConfig.clientId.substring(0, 5)}...');
  
  runApp(const MyApp());
}
```

---

**Next Steps**:
1. Create `.env` file with your credentials
2. Test with `flutter run` or `flutter test`
3. Verify no errors about missing configuration
4. Begin implementing FatSecret API integration
