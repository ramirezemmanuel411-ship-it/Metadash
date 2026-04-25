import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:provider/provider.dart';
import 'shared/palette.dart';
import 'providers/user_state.dart';
import 'features/user_selection/user_selection_screen.dart';
import 'shared/user_settings.dart';
import 'app_shell.dart';

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
      print('Platform error (likely debugger disconnect): ${details.exception}');
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
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // ignore: avoid_print
    print('Note: .env file not found. AI features will be disabled. Create a .env file with your API keys.');
  }

  final firebaseApp = await Firebase.initializeApp();
  // ignore: avoid_print
  print('Firebase initialized: ${firebaseApp.name}');

  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      final cred = await auth.signInAnonymously();
      // ignore: avoid_print
      print('Signed in anonymously: ${cred.user?.uid}');
    } catch (e) {
      // ignore: avoid_print
      print('Anonymous auth failed: $e');
    }
  }

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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _userState = UserState();

    _userState.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // Give the database a moment to initialize
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
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
            surfaceContainer: Palette.dayCard,
            surfaceContainerHigh: Palette.daySecondary,
          ),
          scaffoldBackgroundColor: Palette.dayBackground,
          cardColor: Palette.dayCard,
          dividerColor: Palette.dayDivider,
          dividerTheme: const DividerThemeData(color: Palette.dayDivider, thickness: 1),
          textTheme: const TextTheme(
            displayLarge: TextStyle(color: Palette.dayTextPrimary),
            displayMedium: TextStyle(color: Palette.dayTextPrimary),
            displaySmall: TextStyle(color: Palette.dayTextPrimary),
            headlineLarge: TextStyle(color: Palette.dayTextPrimary),
            headlineMedium: TextStyle(color: Palette.dayTextPrimary),
            headlineSmall: TextStyle(color: Palette.dayTextPrimary),
            titleLarge: TextStyle(color: Palette.dayTextPrimary, fontWeight: FontWeight.bold),
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
            foregroundColor: Palette.dayTextPrimary,
            elevation: 0,
            centerTitle: true,
          ),
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
          dividerTheme: const DividerThemeData(color: Palette.nightDivider, thickness: 1),
          textTheme: const TextTheme(
            displayLarge: TextStyle(color: Palette.nightTextPrimary),
            displayMedium: TextStyle(color: Palette.nightTextPrimary),
            displaySmall: TextStyle(color: Palette.nightTextPrimary),
            headlineLarge: TextStyle(color: Palette.nightTextPrimary),
            headlineMedium: TextStyle(color: Palette.nightTextPrimary),
            headlineSmall: TextStyle(color: Palette.nightTextPrimary),
            titleLarge: TextStyle(color: Palette.nightTextPrimary, fontWeight: FontWeight.bold),
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
            foregroundColor: Palette.nightTextPrimary,
            elevation: 0,
            centerTitle: true,
          ),
        );

        return ChangeNotifierProvider<UserState>.value(
          value: _userState,
          child: MaterialApp(
            title: 'Nutrition',
            theme: theme,
            darkTheme: darkTheme,
            themeMode: mode,
            home: _initialized
                ? (_userState.isLoggedIn
                    ? AppShell(userState: _userState)
                    : UserSelectionScreen(userState: _userState))
                : Scaffold(
                    backgroundColor: mode == ThemeMode.dark ? Palette.nightBackground : Palette.dayBackground,
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Palette.forestGreen,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: mode == ThemeMode.dark ? Palette.nightTextPrimary : Palette.dayTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}


