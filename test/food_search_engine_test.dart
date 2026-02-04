import 'package:flutter_test/flutter_test.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/services/food_search_engine.dart';

/// Simplified integration tests for food search
/// These tests verify the REALISTIC behavior of the search system
void main() {
  group('Food Search - Realistic Tests', () {
    
    test('Search returns clean results without errors', () {
      final items = [
        _food('Coca Cola Original', 'Coca Cola', 140, 355, 'ml'),
        _food('Diet Coke', 'Coca Cola', 0, 355, 'ml'),
        _food('Pepsi Regular', 'Pepsi', 150, 355, 'ml'),
        _food('Diet Pepsi', 'Pepsi', 0, 355, 'ml'),
        _food('Sprite Lemon-Lime', 'Sprite', 140, 355, 'ml'),
      ];

      final results = FoodSearchEngine.search(
        query: 'coke',
        items: items,
        limit: 25,
      );

      expect(results, isNotEmpty);
      expect(results.first.displayTitle, isNotEmpty);
      expect(results.first.displaySubtitle, isNotEmpty);
    });

    test('Search results have clean display formatting', () {
      final items = [
        _food('COCA COLA ORIGINAL TASTE', 'Coca-Cola®', 140, 355, 'ml'),
        _food('Pepsi, cola-flavored beverage, 355ml', 'PepsiCo', 150, 355, 'ml'),
      ];

      final results = FoodSearchEngine.search(
        query: 'cola',
        items: items,
        limit: 25,
      );

      for (final result in results) {
        // No trademark symbols
        expect(result.displayTitle, isNot(contains('®')));
        expect(result.displayTitle, isNot(contains('™')));
        
        // No excessive punctuation (allow occasional dashes/commas in product names)
        final commaCount = result.displayTitle.split(',').length;
        expect(commaCount, lessThanOrEqualTo(3));
      }
    });

    test('Search prioritizes brand match', () {
      final items = [
        _food('Corn Chips', 'Generic', 150, 28, 'g'),
        _food('Lay\'s Classic Chips', 'Lay\'s', 160, 28, 'g'),
        _food('Chip Dip', 'Generic', 140, 30, 'g'),
      ];

      final results = FoodSearchEngine.search(
        query: 'lay',
        items: items,
        limit: 25,
      );

      expect(results.first.displayTitle.toLowerCase(), contains('lay'));
    });

    test('Empty query returns limited results', () {
      final items = List.generate(
        100,
        (i) => _food('Food $i', 'Brand ${i % 5}', 100 + i, 100, 'g'),
      );

      final results = FoodSearchEngine.search(
        query: '',
        items: items,
        limit: 12,
      );

      expect(results.length, lessThanOrEqualTo(12));
    });

    test('Short query returns results without crashing', () {
      final items = [
        _food('Coke', 'Coca Cola', 140, 355, 'ml'),
        _food('Pepsi', 'Pepsi', 150, 355, 'ml'),
      ];

      final results = FoodSearchEngine.search(
        query: 'c',
        items: items,
        limit: 25,
      );

      expect(results, isNotEmpty);
    });

    test('Display subtitle shows brand and serving info', () {
      final item = _food('Coca Cola', 'Coca Cola', 140, 355, 'ml');
      final results = FoodSearchEngine.search(
        query: 'coca',
        items: [item],
      );

      expect(results.isNotEmpty, isTrue);
      final subtitle = results.first.displaySubtitle;
      
      // Should show brand or source
      expect(
        subtitle.toLowerCase().contains('coca') || 
        subtitle.toLowerCase().contains('branded'),
        isTrue,
      );
      
      // Should show calories
      expect(subtitle, contains('cal'));
    });

    test('FoodItemViewModel provides UI-ready data', () {
      final item = _food('Diet Coke', 'Coca Cola', 0, 355, 'ml');
      final viewModel = FoodItemViewModel.fromModel(item);

      expect(viewModel.title, isNotEmpty);
      expect(viewModel.subtitle, isNotEmpty);
      expect(viewModel.avatarLetter, isNotEmpty);
      expect(viewModel.caloriesText, contains('0'));
      expect(viewModel.servingText, contains('355'));
    });

    test('Debounced search respects timing', () async {
      final debouncer = SearchDebouncer(duration: Duration(milliseconds: 100));
      var callCount = 0;

      debouncer.debounce(() {
        callCount++;
      });

      // Wait less than debounce duration - shouldn't execute
      await Future.delayed(Duration(milliseconds: 50));
      expect(callCount, equals(0));

      // Wait for debounce to complete
      await Future.delayed(Duration(milliseconds: 100));
      expect(callCount, equals(1));

      debouncer.dispose();
    });

    test('FoodSearchEngine.quickSearch works', () {
      final items = [
        _food('Coca Cola', 'Coca Cola', 140, 355, 'ml'),
        _food('Pepsi', 'Pepsi', 150, 355, 'ml'),
      ];

      final results = FoodSearchEngine.quickSearch('coke', items);
      expect(results, isNotEmpty);
    });

    test('FoodSearchEngine.debugSearch outputs debug info', () {
      final items = [
        _food('Coca Cola', 'Coca Cola', 140, 355, 'ml'),
      ];

      final results = FoodSearchEngine.debugSearch('cola', items, limit: 25);
      expect(results, isNotEmpty);
    });
  });
}

// =============================================================================
// Helpers
// =============================================================================

FoodModel _food(String name, String brand, int calories, double servingSize, String servingUnit) {
  return FoodModel(
    id: '${name}_${brand}',
    name: name,
    brand: brand,
    servingSize: servingSize,
    servingUnit: servingUnit,
    calories: calories,
    protein: 0,
    carbs: 0,
    fat: 0,
    source: brand == 'Generic' ? 'usda' : 'branded',
  );
}
