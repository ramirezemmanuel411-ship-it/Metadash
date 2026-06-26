import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:metadash/core/logging/app_logger.dart';
import 'package:metadash/features/auth/auth_gate.dart';
import 'package:metadash/firebase_options.dart';
import 'package:metadash/providers/dashboard_layout_provider.dart';
import 'package:metadash/providers/food_plate_provider.dart';
import 'package:metadash/providers/user_state.dart';
import 'package:metadash/shared/palette.dart';
import 'package:metadash/shared/user_settings.dart';
import 'package:metadash/splash_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isReportingError = false;
  void safeRecordFlutterError(FlutterErrorDetails details) {
    if (isReportingError) return;
    isReportingError = true;
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {
      // Crashlytics not available yet; ignore to avoid error loops.
    } finally {
      isReportingError = false;
    }
  }

  bool isReportingPlatformError = false;
  void safeRecordPlatformError(Object error, StackTrace stack) {
    if (isReportingPlatformError) return;
    isReportingPlatformError = true;
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Crashlytics not available yet; ignore to avoid error loops.
    } finally {
      isReportingPlatformError = false;
    }
  }

  // Add global error handler for debugger disconnect crashes
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('ServicesBinding') ||
        details.exception.toString().contains('MethodChannel') ||
        details.exception.toString().contains('PlatformException')) {
      // Silently handle platform-level errors (likely from debugger disconnect)
      // ignore: avoid_print
      AppLogger.d(
        'Platform error (likely debugger disconnect): ${details.exception}',
      );
    } else {
      safeRecordFlutterError(details);
      FlutterError.dumpErrorToConsole(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    safeRecordPlatformError(error, stack);
    return true;
  };

  // Load .env file for AI API keys
  try {
    await dotenv.load();
  } catch (e) {
    // ignore: avoid_print
    AppLogger.d(
      'Note: .env file not found. AI features will be disabled. Create a .env file with your API keys.',
    );
  }

  final firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // ignore: avoid_print
  AppLogger.d('Firebase initialized: ${firebaseApp.name}');

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ),
  );
  await remoteConfig.setDefaults(const {});
  await remoteConfig.fetchAndActivate();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late UserState _userState;
  bool _initialized = false;
  bool _minTimeElapsed = false;

  bool get _showApp => _initialized && _minTimeElapsed;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    // Keep splash visible for at least 2 seconds so tips are readable
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  Future<void> _initializeApp() async {
    _userState = UserState();
    _userState.addListener(() {
      if (mounted) setState(() {});
    });
    // Silently restore the last logged-in user — returning users skip onboarding
    await _userState.autoLoginLastUser();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: UserSettings.themeMode,
      builder: (context, mode, _) {
        final theme = ThemeData(
          useMaterial3: true,
          extensions: [MetaDashColors.day],
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.forestGreen,
            primary: Palette.forestGreen,
            surface: Palette.dayBackground,
            onSurface: Palette.dayTextPrimary,
            onSurfaceVariant: Palette.dayTextSecondary,
            secondary: Palette.forestGreen,
            onSecondary: Colors.white,
            surfaceContainer: Palette.dayCard,
            surfaceContainerHigh: Palette.daySecondary,
          ),
          scaffoldBackgroundColor: Palette.dayBackground,
          cardColor: Palette.dayCard,
          dividerColor: Palette.dayDivider,
          dividerTheme: const DividerThemeData(
            color: Palette.dayDivider,
            thickness: 1,
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(color: Palette.dayTextPrimary),
            displayMedium: TextStyle(color: Palette.dayTextPrimary),
            displaySmall: TextStyle(color: Palette.dayTextPrimary),
            headlineLarge: TextStyle(color: Palette.dayTextPrimary),
            headlineMedium: TextStyle(color: Palette.dayTextPrimary),
            headlineSmall: TextStyle(color: Palette.dayTextPrimary),
            titleLarge: TextStyle(
              color: Palette.dayTextPrimary,
              fontWeight: FontWeight.bold,
            ),
            titleMedium: TextStyle(color: Palette.dayTextPrimary),
            titleSmall: TextStyle(color: Palette.dayTextPrimary),
            bodyLarge: TextStyle(color: Palette.dayTextPrimary),
            bodyMedium: TextStyle(color: Palette.dayTextPrimary),
            bodySmall: TextStyle(color: Palette.dayTextSecondary),
            labelLarge: TextStyle(color: Palette.dayTextPrimary),
            labelSmall: TextStyle(color: Palette.dayTextSecondary),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Palette.dayBackground,
            foregroundColor: Palette.forestGreen,
            elevation: 0,
            centerTitle: true,
          ),
          listTileTheme: const ListTileThemeData(
            textColor: Palette.dayTextPrimary,
            subtitleTextStyle: TextStyle(color: Palette.dayTextSecondary),
            iconColor: Palette.dayTextSecondary,
          ),
          iconTheme: const IconThemeData(color: Palette.dayTextPrimary),
        );

        final darkTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          extensions: [MetaDashColors.night],
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.nightAccentBlue,
            brightness: Brightness.dark,
            primary: Palette.nightAccentBlue,
            surface: Palette.nightBackground,
            onSurface: Palette.nightTextPrimary,
            surfaceContainer: Palette.nightCard,
            surfaceContainerHigh: Palette.nightSecondary,
          ),
          scaffoldBackgroundColor: Palette.nightBackground,
          cardColor: Palette.nightCard,
          dividerColor: Palette.nightDivider,
          dividerTheme: const DividerThemeData(
            color: Palette.nightDivider,
            thickness: 1,
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(color: Palette.nightTextPrimary),
            displayMedium: TextStyle(color: Palette.nightTextPrimary),
            displaySmall: TextStyle(color: Palette.nightTextPrimary),
            headlineLarge: TextStyle(color: Palette.nightTextPrimary),
            headlineMedium: TextStyle(color: Palette.nightTextPrimary),
            headlineSmall: TextStyle(color: Palette.nightTextPrimary),
            titleLarge: TextStyle(
              color: Palette.nightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
            titleMedium: TextStyle(color: Palette.nightTextPrimary),
            titleSmall: TextStyle(color: Palette.nightTextPrimary),
            bodyLarge: TextStyle(color: Palette.nightTextPrimary),
            bodyMedium: TextStyle(color: Palette.nightTextPrimary),
            bodySmall: TextStyle(color: Palette.nightTextSecondary),
            labelLarge: TextStyle(color: Palette.nightTextPrimary),
            labelSmall: TextStyle(color: Palette.nightTextSecondary),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Palette.nightBackground,
            foregroundColor: Palette.nightAccentBlue,
            elevation: 0,
            centerTitle: true,
          ),
        );

        return MultiProvider(
          providers: [
            ChangeNotifierProvider<UserState>.value(value: _userState),
            ChangeNotifierProvider<DashboardLayoutProvider>(
              create: (_) => DashboardLayoutProvider(),
            ),
            ChangeNotifierProvider<FoodPlateProvider>(
              create: (_) => FoodPlateProvider(),
            ),
          ],
          child: MaterialApp(
            title: 'Nutrition',
            theme: theme,
            darkTheme: darkTheme,
            themeMode: mode,
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _showApp
                  ? AuthGate(userState: _userState)
                  : const SplashScreen(),
            ),
          ),
        );
      },
    );
  }
}
