import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'data/repositories/search_repository.dart';
import 'presentation/bloc/food_search_bloc.dart';
import 'presentation/screens/fast_food_search_screen.dart';

/// Example of how to integrate the fast food search into your app
/// 
/// This file demonstrates:
/// 1. Providing the BLoC at the app level
/// 2. Navigating to the search screen
/// 3. Alternative: providing BLoC at route level
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metadash Food Search Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metadash'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _navigateToFastSearch(context),
              icon: const Icon(Icons.search),
              label: const Text('Open Fast Food Search'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Fast, local-first food search\nwith caching & debouncing',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to fast search screen with BLoC
  void _navigateToFastSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => FoodSearchBloc(
            repository: SearchRepository(),
          ),
          child: const FastFoodSearchScreen(),
        ),
      ),
    );
  }
}

// ============================================================
// ALTERNATIVE: App-level BLoC Provider
// ============================================================

/// If you want to keep the BLoC alive across navigation,
/// provide it at the app level:
///
/// ```dart
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MultiBlocProvider(
///       providers: [
///         BlocProvider(
///           create: (_) => FoodSearchBloc(
///             repository: SearchRepository(),
///           ),
///         ),
///         // Add other BLoCs here
///       ],
///       child: MaterialApp(
///         home: HomeScreen(),
///       ),
///     );
///   }
/// }
/// ```
///
/// Then navigate without creating a new provider:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => FastFoodSearchScreen()),
/// );
/// ```

// ============================================================
// INTEGRATION WITH EXISTING FOOD SEARCH
// ============================================================

/// To integrate with your existing food search screen:
///
/// 1. Replace your current search widget with FastFoodSearchScreen
///
/// 2. If you need to pass the selected food back:
/// ```dart
/// final result = await Navigator.push<FoodModel>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => BlocProvider(
///       create: (_) => FoodSearchBloc(repository: SearchRepository()),
///       child: FastFoodSearchScreen(
///         onFoodSelected: (food) => Navigator.pop(context, food),
///       ),
///     ),
///   ),
/// );
/// 
/// if (result != null) {
///   // Use the selected food
/// }
/// ```
///
/// 3. To customize the UI, extend FastFoodSearchScreen and override
///    the build methods you want to change

// ============================================================
// CLEANUP & MAINTENANCE
// ============================================================

/// Schedule periodic cleanup (e.g., on app start or settings):
/// ```dart
/// void initState() {
///   super.initState();
///   _cleanupOldData();
/// }
/// 
/// Future<void> _cleanupOldData() async {
///   final repo = SearchRepository();
///   await repo.cleanupOldData();
/// }
/// ```

// ============================================================
// DEBUGGING & MONITORING
// ============================================================

/// Check database stats:
/// ```dart
/// final repo = SearchRepository();
/// final stats = await repo.getStats();
/// print('Foods cached: ${stats['foods']}');
/// print('Searches cached: ${stats['cached_searches']}');
/// print('Memory cache size: ${stats['memory_cache']}');
/// ```
