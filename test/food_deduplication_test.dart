import 'package:flutter_test/flutter_test.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/services/universal_food_deduper.dart';

void main() {
  group('FoodDeduplicationService - Brand & Core Normalization', () {
    
    test('Coca Cola variants normalize to same brand (coca-cola)', () {
      expect(UniversalFoodDeduper.normalizeBrand('Coca Cola', null), 'coca-cola');
      expect(UniversalFoodDeduper.normalizeBrand('Coke', null), 'coca-cola');
      expect(UniversalFoodDeduper.normalizeBrand('Coca-Cola', null), 'coca-cola');
      expect(UniversalFoodDeduper.normalizeBrand('coca cola company', null), 'coca-cola');
      expect(UniversalFoodDeduper.normalizeBrand('the coca-cola company', null), 'coca-cola');
    });
    
    test('USDA and null brand do not become coca-cola', () {
      expect(UniversalFoodDeduper.normalizeBrand('USDA', null), 'generic');
      expect(UniversalFoodDeduper.normalizeBrand('?', null), 'generic');
      expect(UniversalFoodDeduper.normalizeBrand(null, 'some other name'), 'generic');
    });
    
    test('Coca Cola Coke Brand and Coca cola Goût Original share same family signature', () {
      final sig1 = UniversalFoodDeduper.buildFamilyKey(
        name: 'Coca Cola Coke Brand',
        brand: 'Coca-Cola',
        query: 'coke',
      );
      
      final sig2 = UniversalFoodDeduper.buildFamilyKey(
        name: 'Coca cola Goût Original',
        brand: 'coke',
        query: 'coke',
      );
      
      print('Sig1: $sig1');
      print('Sig2: $sig2');
      
      expect(sig1, 'coca-cola|cola|regular|none',
        reason: 'Coca Cola Coke Brand should normalize to coca-cola|cola|regular|none');
      expect(sig2, 'coca-cola|cola|regular|none',
        reason: 'Coca cola Goût Original should normalize to coca-cola|cola|regular|none');
      expect(sig1, sig2,
        reason: 'Both variants should share identical family signature');
    });
    
    test('Language variants all collapse to same core (cola)', () {
      // Test core inference with different language variants
      final variants = ProductVariants(
        dietType: 'regular',
        flavor: 'none',
        caffeine: '',
        format: '',
        fatLevel: '',
        prep: '',
      );
      
      expect(
        UniversalFoodDeduper.inferCoreName(
          'original taste',
          variants,
          brandNorm: 'coca-cola',
          queryNorm: 'coke',
        ),
        'cola',
        reason: 'Original Taste with Coca-Cola brand should infer core as cola',
      );
      
      expect(
        UniversalFoodDeduper.inferCoreName(
          'goût original',
          variants,
          brandNorm: 'coca-cola',
          queryNorm: 'coke',
        ),
        'cola',
        reason: 'Goût Original with Coca-Cola brand should infer core as cola',
      );
      
      expect(
        UniversalFoodDeduper.inferCoreName(
          'sabor original',
          variants,
          brandNorm: 'coca-cola',
          queryNorm: 'coke',
        ),
        'cola',
        reason: 'Sabor Original with Coca-Cola brand should infer core as cola',
      );
    });
    
    test('Deduplication collapses all Coke variants into single canonical', () {
      final items = [
        FoodModel(
          id: '1',
          name: 'Coca Cola Coke Brand',
          brand: 'Coca-Cola',
          calories: 44,
          protein: 0,
          carbs: 11,
          fat: 0,
          servingSize: 100,
          servingUnit: 'g',
          source: 'open_food_facts',
        ),
        FoodModel(
          id: '2',
          name: 'Coca cola Goût Original',
          brand: 'coke',
          calories: 30,
          protein: 0,
          carbs: 11,
          fat: 0,
          servingSize: 100,
          servingUnit: 'g',
          source: 'open_food_facts',
        ),
        FoodModel(
          id: '3',
          name: 'Original Taste Coke',
          brand: null,
          calories: 42,
          protein: 0,
          carbs: 10,
          fat: 0,
          servingSize: 100,
          servingUnit: 'g',
          source: 'usda',
        ),
        FoodModel(
          id: '4',
          name: 'Diet Coke',
          brand: 'Coca-Cola',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          servingSize: 100,
          servingUnit: 'g',
          source: 'open_food_facts',
        ),
      ];

      final result = UniversalFoodDeduper.deduplicateByFamily(
        items: items,
        query: 'coke',
        debug: false,
      );

      // Should have at least 2 families: regular coke and diet coke
      expect(result.groupedResults.length, greaterThanOrEqualTo(2),
        reason: 'Should collapse regular variants but keep diet separate');
      
      // Verify no "Original Taste", "Goût Original", "Sabor Original" as separate items
      expect(
        result.groupedResults.where((item) => 
          item.name.toLowerCase().contains('original taste') ||
          item.name.toLowerCase().contains('goût original') ||
          item.name.toLowerCase().contains('sabor original')
        ).length,
        0,
        reason: 'All language variants should be collapsed into canonical',
      );
    });

    test('Jaro-Winkler similarity works correctly', () {
      expect(UniversalFoodDeduper.jaroWinklerSimilarity('coca cola', 'coca cola'), 1.0);
      expect(UniversalFoodDeduper.jaroWinklerSimilarity('coca cola', 'coke'), greaterThan(0.8));
      expect(UniversalFoodDeduper.jaroWinklerSimilarity('transformation', 'coke'), lessThan(0.5));
    });

    test('Token overlap similarity works correctly', () {
      expect(UniversalFoodDeduper.tokenOverlapSimilarity('coca cola original', 'coca cola coke'), 0.5);
      expect(UniversalFoodDeduper.tokenOverlapSimilarity('diet coke', 'diet coke'), 1.0);
    });

    test('Diet and Zero variants remain separate families', () {
      final items = [
        FoodModel(
          id: '1',
          name: 'Coca Cola',
          brand: 'Coca-Cola',
          calories: 44,
          protein: 0,
          carbs: 11,
          fat: 0,
          servingSize: 100,
          servingUnit: 'g',
          source: 'usda',
        ),
        FoodModel(
          id: '2',
          name: 'Diet Coke',
          brand: 'Coca-Cola',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          servingSize: 100,
          servingUnit: 'g',
          source: 'open_food_facts',
        ),
        FoodModel(
          id: '3',
          name: 'Coke Zero',
          brand: 'Coca-Cola',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          servingSize: 100,
          servingUnit: 'g',
          source: 'open_food_facts',
        ),
      ];

      final result = UniversalFoodDeduper.deduplicateByFamily(
        items: items,
        query: 'coke',
      );

      expect(result.groupedResults.length, 3,
        reason: 'Regular, Diet, and Zero should be 3 separate families');
    });
  });
}
