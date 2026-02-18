import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'shared/palette.dart';
import 'providers/user_state.dart';
import 'features/user_selection/user_selection_screen.dart';
import 'app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env file for AI API keys
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // ignore: avoid_print
    print('Note: .env file not found. AI features will be disabled. Create a .env file with your API keys.');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Palette.forestGreen),
      scaffoldBackgroundColor: Palette.warmNeutral,
    );

    return MaterialApp(
      title: 'Nutrition',
      theme: theme,
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late UserState userState;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    userState = UserState();
    
    // Listen for changes to rebuild when user logs in
    userState.addListener(() {
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
    if (!_initialized) {
      return Scaffold(
        backgroundColor: Palette.warmNeutral,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Palette.forestGreen),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return ChangeNotifierProvider<UserState>.value(
      value: userState,
      child: userState.isLoggedIn
          ? AppShell(userState: userState)
          : UserSelectionScreen(userState: userState),
    );
  }
}


