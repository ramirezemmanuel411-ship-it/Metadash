import 'package:flutter_test/flutter_test.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/services/food_search_pipeline.dart';

void main() {
  test('DEBUG: Trace Pepsi variants through pipeline', () {
    // Create test Pepsi items with DISTINCT properties
    final items = [
      FoodModel(
        id: '1',
        name: 'Pepsi',
        brand: 'PepsiCo',
        servingSize: 355,
        servingUnit: 'ml',
        calories: 150,
        protein: 0,
        carbs: 41,
        fat: 0,
        source: 'branded',
      ),
      FoodModel(
        id: '2',
        name: 'Diet Pepsi',
        brand: 'PepsiCo',
        servingSize: 355,
        servingUnit: 'ml',
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        source: 'branded',
      ),
      FoodModel(
        id: '3',
        name: 'Pepsi Zero Sugar',
        brand: 'PepsiCo',
        servingSize: 355,
        servingUnit: 'ml',
        calories: 1,
        protein: 0,
        carbs: 0,
        fat: 0,
        source: 'branded',
      ),
      FoodModel(
        id: '4',
        name: 'Pepsi Wild Cherry',
        brand: 'PepsiCo',
        servingSize: 355,
        servingUnit: 'ml',
        calories: 160,
        protein: 0,
        carbs: 42,
        fat: 0,
        source: 'branded',
      ),
    ];

    print('\n=== INPUT ITEMS ===');
    for (var item in items) {
      print('ID: ${item.id}');
      print('  Name: ${item.name}');
      print('  Calories: ${item.calories}');
      print('  DisplayTitle: ${item.displayTitle}');
      print('');
    }

    print('\n=== RUNNING PIPELINE ===');
    final results = FoodSearchPipeline.process(
      rawResults: items,
      query: 'pepsi',
      maxResults: 25,
      debug: true,
    );

    print('\n=== OUTPUT RESULTS ===');
    print('Count: ${results.length}');
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      print('\n[$i] ${r.displayTitle}');
      print('    ID: ${r.id}');
      print('    Calories: ${r.calories}');
      print('    DisplaySubtitle: ${r.displaySubtitle}');
    }

    // Verify we got all 4 variants
    expect(results.length, equals(4), reason: 'Should keep all Pepsi variants');
    
    // Verify they're all different
    final ids = results.map((r) => r.id).toSet();
    expect(ids.length, equals(4), reason: 'All should have different IDs');
    
    // Verify they're properly named
    expect(results.map((r) => r.displayTitle).toList(), 
      containsAll(['Pepsi', 'Diet Pepsi', 'Pepsi Zero Sugar', 'Pepsi Wild Cherry']));
  });
}
