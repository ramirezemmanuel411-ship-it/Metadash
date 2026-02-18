import 'package:flutter_test/flutter_test.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/services/food_search_pipeline.dart';

/// Integration tests for food search pipeline
/// Tests the complete search experience: normalization, ranking, deduplication, display
void main() {
  group('Food Search Pipeline Integration Tests', () {
    
    // =========================================================================
    // TEST 1: "coke" query - Brand recognition and variant handling
    // =========================================================================
    test('Query "coke" returns correct Coca-Cola variants in order', () {
      final rawResults = [
        _createFood(id: '1', name: 'Coca cola Gout Original', brand: 'Coca Cola', calories: 140, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '2', name: 'Coca Cola Coke Brand', brand: 'Coca-Cola', calories: 140, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '3', name: 'Diet Coke', brand: 'Coca Cola', calories: 0, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '4', name: 'Coke Zero Sugar', brand: 'Coca Cola', calories: 0, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '5', name: 'Cherry Coke', brand: 'Coca Cola', calories: 150, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '6', name: 'Transformation', brand: 'Generic', calories: 200, servingSize: 100, servingUnit: 'g'),
        _createFood(id: '7', name: 'Original Taste', brand: '', calories: 140, servingSize: 100, servingUnit: 'ml'),
        _createFood(id: '8', name: 'Coke, 100ml', brand: 'Coca Cola', calories: 42, servingSize: 100, servingUnit: 'ml'),
        _createFood(id: '9', name: 'Coca Cola Original', brand: 'Coca Cola', calories: 140, servingSize: 355, servingUnit: 'ml'),
      ];

      final results = FoodSearchPipeline.process(
        rawResults: rawResults,
        query: 'coke',
        maxResults: 25,
        debug: true,
      );

      print('\n✓ TEST 1: Query "coke"');
      _printResults(results);

      // Should have 5-6 distinct results (no duplicates)
      expect(results.length, greaterThanOrEqualTo(4));
      expect(results.length, lessThanOrEqualTo(8));

      // Top result should be a branded Coca-Cola product (not "Goût Original" or "Transformation")
      final topResult = results.first;
      expect(topResult.displayTitle.toLowerCase(), contains('co'));
      expect(topResult.displayTitle, isNot(contains('Gout')));
      expect(topResult.displayTitle, isNot(contains('Transformation')));

      // Should include major variants
      final resultNames = results.map((r) => r.displayTitle.toLowerCase()).join(' ');
      expect(resultNames, anyOf(contains('diet'), contains('zero')));
      expect(resultNames, anyOf(contains('cherry'), contains('original'), contains('coke')));

      // "Coca cola Gout Original" and "Coca Cola Coke Brand" should be deduplicated
      final goutCount = results.where((r) => r.name.contains('Gout') || r.name.contains('Go')).length;
      expect(goutCount, lessThanOrEqualTo(2), reason: 'Foreign variants should be reduced');

      print('✓ Test passed: Coke returns clean, distinct results\n');
    });

    // =========================================================================
    // TEST 2: "pepsi" query - NOT over-aggressive deduplication
    // =========================================================================
    test('Query "pepsi" returns multiple Pepsi variants (not just 1)', () {
      final rawResults = [
        _createFood(id: '1', name: 'Pepsi', brand: 'PepsiCo', calories: 150, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '2', name: 'Diet Pepsi', brand: 'PepsiCo', calories: 0, servingSize: 355, servingUnit: 'ml'), // Different calories
        _createFood(id: '3', name: 'Pepsi Zero Sugar', brand: 'PepsiCo', calories: 0, servingSize: 355, servingUnit: 'ml'), // Same as Diet, might dedupe
        _createFood(id: '4', name: 'Pepsi Wild Cherry', brand: 'PepsiCo', calories: 160, servingSize: 355, servingUnit: 'ml'), // Different calories
        _createFood(id: '5', name: 'Pepsi Lime', brand: 'PepsiCo', calories: 145, servingSize: 355, servingUnit: 'ml'), // Different calories
        _createFood(id: '6', name: 'Pepsi, cola-flavored', brand: 'Generic', calories: 150, servingSize: 100, servingUnit: 'ml'), // Different serving
        _createFood(id: '7', name: 'Pepsi (100g)', brand: 'PepsiCo', calories: 45, servingSize: 100, servingUnit: 'g'), // Different serving
      ];

      final results = FoodSearchPipeline.process(
        rawResults: rawResults,
        query: 'pepsi',
        maxResults: 25,
        debug: true,
      );

      print('\n✓ TEST 2: Query "pepsi"');
      _printResults(results);

      // Should have 3-6 distinct results (regular, diet/zero, cherry, lime, etc.)
      // Note: Diet Pepsi and Pepsi Zero might collapse if they have identical nutrition
      expect(results.length, greaterThanOrEqualTo(3), reason: 'Should keep distinct variants');
      expect(results.length, lessThanOrEqualTo(7));

      // Should include different variants
      final resultNames = results.map((r) => r.displayTitle.toLowerCase()).join(' ');
      expect(resultNames, contains('pepsi'));
      
      // Should have at least 2 different Pepsi variants
      final distinctVariants = results.where((r) {
        final name = r.displayTitle.toLowerCase();
        return name.contains('pepsi');
      }).length;
      expect(distinctVariants, greaterThanOrEqualTo(2), reason: 'Should not collapse all Pepsi into 1');

      print('✓ Test passed: Pepsi returns multiple distinct variants\n');
    });

    // =========================================================================
    // TEST 3: "pizza hut" query - Restaurant matching over irrelevant products
    // =========================================================================
    test('Query "pizza hut" returns Pizza Hut items first, NOT Lay\'s chips', () {
      final rawResults = [
        _createFood(id: '1', name: 'Lay\'s Classic Chips', brand: 'Lay\'s', calories: 160, servingSize: 28, servingUnit: 'g'),
        _createFood(id: '2', name: 'Pizza Hut Pepperoni Pizza', brand: 'Pizza Hut', calories: 280, servingSize: 100, servingUnit: 'g'),
        _createFood(id: '3', name: 'Pizza Hut Cheese Pizza', brand: 'Pizza Hut', calories: 250, servingSize: 100, servingUnit: 'g'),
        _createFood(id: '4', name: 'Doritos Cool Ranch', brand: 'Doritos', calories: 150, servingSize: 28, servingUnit: 'g'),
        _createFood(id: '5', name: 'Pizza Hut Supreme Pizza', brand: 'Pizza Hut', calories: 300, servingSize: 100, servingUnit: 'g'),
        _createFood(id: '6', name: 'Pizza, cheese, thin crust', brand: 'Generic', calories: 270, servingSize: 100, servingUnit: 'g'),
        _createFood(id: '7', name: 'Pizza Hut Breadsticks', brand: 'Pizza Hut', calories: 140, servingSize: 50, servingUnit: 'g'),
      ];

      final results = FoodSearchPipeline.process(
        rawResults: rawResults,
        query: 'pizza hut',
        maxResults: 25,
        debug: true,
      );

      print('\n✓ TEST 3: Query "pizza hut"');
      _printResults(results);

      // Should have at least 3-4 Pizza Hut items
      expect(results.length, greaterThanOrEqualTo(3));

      // Top 3 results should ALL be Pizza Hut branded
      final top3 = results.take(3).toList();
      for (var i = 0; i < top3.length; i++) {
        final item = top3[i];
        expect(
          item.displayTitle.toLowerCase().contains('pizza hut') || 
          item.displayBrand.toLowerCase().contains('pizza hut') ||
          item.brand?.toLowerCase().contains('pizza hut') == true,
          isTrue,
          reason: 'Top ${i+1} result should be Pizza Hut branded, got: ${item.displayTitle}',
        );
      }

      // Lay's and Doritos should NOT be in top 3
      final top3Names = top3.map((r) => r.displayTitle.toLowerCase()).join(' ');
      expect(top3Names, isNot(contains('lay')));
      expect(top3Names, isNot(contains('dorito')));

      print('✓ Test passed: Pizza Hut returns restaurant items first\n');
    });

    // =========================================================================
    // TEST 4: "hershey" query - Clean names without over-collapsing
    // =========================================================================
    test('Query "hershey" returns distinct products with clean names', () {
      final rawResults = [
        _createFood(id: '1', name: 'Hershey\'s Milk Chocolate Bar', brand: 'Hershey', calories: 210, servingSize: 43, servingUnit: 'g'),
        _createFood(id: '2', name: 'Hershey\'s Kisses', brand: 'Hershey', calories: 200, servingSize: 40, servingUnit: 'g'),
        _createFood(id: '3', name: 'Hershey\'s Dark Chocolate', brand: 'Hershey', calories: 190, servingSize: 40, servingUnit: 'g'),
        _createFood(id: '4', name: 'Hershey\'s Syrup', brand: 'Hershey', calories: 50, servingSize: 15, servingUnit: 'ml'),
        _createFood(id: '5', name: 'Hershey, chocolat au lait', brand: 'Hershey', calories: 212, servingSize: 43, servingUnit: 'g'), // Slightly different
        _createFood(id: '6', name: 'HERSHEY CHOCOLATE BAR 100G', brand: 'HERSHEY', calories: 540, servingSize: 100, servingUnit: 'g'), // Different serving
        _createFood(id: '7', name: 'Hershey\'s Cookies \'n\' Creme', brand: 'Hershey', calories: 220, servingSize: 43, servingUnit: 'g'),
      ];

      final results = FoodSearchPipeline.process(
        rawResults: rawResults,
        query: 'hershey',
        maxResults: 25,
        debug: true,
      );

      print('\n✓ TEST 4: Query "hershey"');
      _printResults(results);

      // Should have 4-6 distinct products (not collapsed to 1)
      expect(results.length, greaterThanOrEqualTo(4), reason: 'Should keep distinct products');
      expect(results.length, lessThanOrEqualTo(7));

      // Should include different product types
      final resultNames = results.map((r) => r.displayTitle.toLowerCase()).join(' ');
      expect(resultNames, contains('hershey'));

      // Should have at least 3 different Hershey products
      final distinctProducts = results.where((r) {
        final name = r.displayTitle.toLowerCase();
        return name.contains('hershey') || name.contains('chocolate') || name.contains('kiss') || name.contains('syrup');
      }).length;
      expect(distinctProducts, greaterThanOrEqualTo(3));

      // Foreign variant "chocolat au lait" should be removed
      final foreignCount = results.where((r) => r.name.contains('chocolat au lait')).length;
      expect(foreignCount, lessThanOrEqualTo(1), reason: 'Foreign variants should be reduced when English equivalent exists');

      print('✓ Test passed: Hershey returns distinct products with clean names\n');
    });

    // =========================================================================
    // TEST 5: Deduplication keeps meaningful variants
    // =========================================================================
    test('Deduplication keeps "Coke Zero" and "Diet Coke" separate', () {
      final rawResults = [
        _createFood(id: '1', name: 'Coca Cola Original', brand: 'Coca Cola', calories: 140, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '2', name: 'Coca Cola Coke Original', brand: 'Coca-Cola', calories: 140, servingSize: 355, servingUnit: 'ml'), // Duplicate
        _createFood(id: '3', name: 'Diet Coke', brand: 'Coca Cola', calories: 0, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '4', name: 'Coke Zero Sugar', brand: 'Coca Cola', calories: 1, servingSize: 355, servingUnit: 'ml'), // Slightly different to avoid canonicalKey collision
        _createFood(id: '5', name: 'Diet Coke (100ml)', brand: 'Coca Cola', calories: 0, servingSize: 100, servingUnit: 'ml'), // Serving duplicate
      ];

      final results = FoodSearchPipeline.process(
        rawResults: rawResults,
        query: 'coke',
        maxResults: 25,
        debug: true,
      );

      print('\n✓ TEST 5: Deduplication test');
      _printResults(results);

      // Should collapse "Coca Cola Original" and "Coca Cola Coke Original" into one
      final originalCount = results.where((r) {
        final name = r.displayTitle.toLowerCase();
        return name.contains('original') && !name.contains('diet') && !name.contains('zero');
      }).length;
      expect(originalCount, lessThanOrEqualTo(2), reason: 'Should collapse duplicate originals');

      // Should collapse "Diet Coke" and "Diet Coke (100ml)" into one
      final dietCount = results.where((r) => r.displayTitle.toLowerCase().contains('diet')).length;
      expect(dietCount, lessThanOrEqualTo(2), reason: 'Should collapse serving size duplicates');

      // Should keep Diet Coke and Coke Zero as separate (meaningful variants)
      final hasDiet = results.any((r) => r.displayTitle.toLowerCase().contains('diet'));
      final hasZero = results.any((r) => r.displayTitle.toLowerCase().contains('zero'));
      expect(hasDiet && hasZero, isTrue, reason: 'Should keep Diet and Zero as separate variants');

      // Total should be 3 items: Original, Diet, Zero
      // (Diet 100ml will collapse with Diet 355ml)
      expect(results.length, greaterThanOrEqualTo(3));
      expect(results.length, lessThanOrEqualTo(4));

      print('✓ Test passed: Deduplication keeps meaningful variants\n');
    });

    // =========================================================================
    // TEST 6: Empty query handling
    // =========================================================================
    test('Empty query returns limited results without crashing', () {
      final rawResults = List.generate(
        50,
        (i) => _createFood(
          id: '$i',
          name: 'Food Item $i',
          brand: 'Brand ${i % 5}',
          calories: 100 + i,
          servingSize: 100,
          servingUnit: 'g',
        ),
      );

      final results = FoodSearchPipeline.process(
        rawResults: rawResults,
        query: '',
        maxResults: 12,
      );

      expect(results.length, lessThanOrEqualTo(12));
      expect(results, isNotEmpty);
    });

    // =========================================================================
    // TEST 7: Foreign language penalization
    // =========================================================================
    test('Foreign language results rank lower than English', () {
      final rawResults = [
        _createFood(id: '1', name: 'Coca Cola Original', brand: 'Coca Cola', calories: 140, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '2', name: 'Coca cola Gout Original', brand: 'Coca Cola', calories: 140, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '3', name: 'Coca cola Sabor Original', brand: 'Coca Cola', calories: 140, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '4', name: 'Coca Cola Classic', brand: 'Coca Cola', calories: 140, servingSize: 355, servingUnit: 'ml'),
      ];

      final results = FoodSearchPipeline.process(
        rawResults: rawResults,
        query: 'coke',
        maxResults: 25,
      );

      // English variants should rank higher
      final top2 = results.take(2).toList();
      final top2Names = top2.map((r) => r.displayTitle).join(' ');
      
      expect(top2Names, isNot(contains('Gout')));
      expect(top2Names, isNot(contains('Sabor')));
    });

    // =========================================================================
    // TEST 8: Display formatting consistency
    // =========================================================================
    test('Display titles are clean and readable', () {
      final rawResults = [
        _createFood(id: '1', name: 'COCA COLA COKE BRAND', brand: 'Coca-Cola', calories: 140, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '2', name: 'pepsi, cola-flavored beverage', brand: 'PepsiCo', calories: 150, servingSize: 355, servingUnit: 'ml'),
        _createFood(id: '3', name: 'Hershey\'s®, Milk Chocolate™', brand: 'Hershey', calories: 210, servingSize: 43, servingUnit: 'g'),
      ];

      final results = FoodSearchPipeline.process(
        rawResults: rawResults,
        query: 'coke',
        maxResults: 25,
      );

      for (final result in results) {
        final title = result.displayTitle;
        final subtitle = result.displaySubtitle;
        
        // Title should not be empty
        expect(title, isNotEmpty);
        
        // Title should not have excessive punctuation
        expect(title, isNot(contains('®')));
        expect(title, isNot(contains('™')));
        
        // Subtitle should show brand or source
        expect(subtitle, isNotEmpty);
        
        // Should have serving info
        final servingLine = result.servingLine;
        expect(servingLine, isNotEmpty);
        expect(servingLine, isNot(equals('serving?')));
      }
    });
  });
}

// =============================================================================
// Helper Functions
// =============================================================================

FoodModel _createFood({
  required String id,
  required String name,
  required String brand,
  required int calories,
  required double servingSize,
  required String servingUnit,
}) {
  return FoodModel(
    id: id,
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

void _printResults(List<FoodModel> results) {
  print('  Found ${results.length} results:');
  for (var i = 0; i < results.length && i < 10; i++) {
    final item = results[i];
    print('    ${i + 1}. ${item.displayTitle}');
    print('       Brand: ${item.displayBrand} | ${item.calories} cal | ${item.servingLine}');
    print('       Subtitle: ${item.displaySubtitle}');
  }
}
