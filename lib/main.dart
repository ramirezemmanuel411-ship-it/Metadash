import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:provider/provider.dart';
import 'shared/palette.dart';
import 'providers/user_state.dart';
import 'features/user_selection/user_selection_screen.dart';
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

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

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
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Palette.forestGreen),
      scaffoldBackgroundColor: Palette.warmNeutral,
    );

    return ChangeNotifierProvider<UserState>.value(
      value: _userState,
      child: MaterialApp(
        title: 'Nutrition',
        theme: theme,
        home: _initialized
            ? (_userState.isLoggedIn
                ? AppShell(userState: _userState)
                : UserSelectionScreen(userState: _userState))
            : Scaffold(
                backgroundColor: Palette.warmNeutral,
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
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}


