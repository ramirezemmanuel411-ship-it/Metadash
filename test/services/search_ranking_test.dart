import 'package:flutter_test/flutter_test.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/services/search_normalization.dart';
import 'package:metadash/services/search_ranking.dart';

void main() {
  group('SearchNormalization', () {
    group('normalizeText', () {
      test('removes punctuation', () {
        expect(SearchNormalization.normalizeText('Coca-Cola'), 'coca cola');
        expect(SearchNormalization.normalizeText('Coca_Cola'), 'coca cola');
      });

      test('collapses multiple spaces', () {
        expect(SearchNormalization.normalizeText('Coca  Cola'), 'coca cola');
        expect(SearchNormalization.normalizeText('Coca   Cola'), 'coca cola');
      });

      test('lowercases text', () {
        expect(SearchNormalization.normalizeText('COCA COLA'), 'coca cola');
        expect(SearchNormalization.normalizeText('CoCA ColA'), 'coca cola');
      });

      test('trims whitespace', () {
        expect(SearchNormalization.normalizeText('  Coca Cola  '), 'coca cola');
      });

      test('handles empty strings', () {
        expect(SearchNormalization.normalizeText(''), '');
        expect(SearchNormalization.normalizeText('   '), '');
      });
    });

    group('canonicalProductName', () {
      test('removes brand duplication', () {
        final item = FoodModel(
          id: '1',
          name: 'Coca Cola Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coca Cola Coke',
          brandName: 'Coca Cola',
        );
        final result = SearchNormalization.canonicalProductName(item);
        // Should not be "Coca Cola Coke" but cleaned
        expect(result, isNotEmpty);
      });

      test('handles fragment variants', () {
        final item = FoodModel(
          id: '1',
          name: 'Coke Lime Lime',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke Lime Lime',
          brandName: 'Coca Cola',
        );
        final result = SearchNormalization.canonicalProductName(item);
        // Should remove duplicate "Lime Lime"
        expect(result.contains('Lime Lime'), false);
      });

      test('strips measurement words', () {
        final item = FoodModel(
          id: '1',
          name: 'Coke 355 ml',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke 355 ml',
          brandName: 'Coca Cola',
        );
        final result = SearchNormalization.canonicalProductName(item);
        expect(result.contains('ml'), false);
      });
    });

    group('createDedupeKey', () {
      test('creates consistent key format', () {
        final item = FoodModel(
          id: '1',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
          brandName: 'Coca Cola',
          category: 'beverages',
        );
        final key = createDedupeKey(item);
        expect(key.contains('|'), true);
        final parts = key.split('|');
        expect(parts.length, 3);
      });

      test('normalizes key for case-insensitivity', () {
        final item1 = FoodModel(
          id: '1',
          name: 'COKE',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'COKE',
          brandName: 'Coca Cola',
        );
        final item2 = FoodModel(
          id: '2',
          name: 'coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'coke',
          brandName: 'coca cola',
        );
        expect(createDedupeKey(item1), createDedupeKey(item2));
      });
    });

    group('displayTitle', () {
      test('includes brand and product when both exist', () {
        final item = FoodModel(
          id: '1',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
          brandName: 'Coca Cola',
        );
        final title = SearchNormalization.displayTitle(item);
        expect(title, contains('Coca Cola'));
        expect(title, contains('Coke'));
      });

      test('shows product only when no brand', () {
        final item = FoodModel(
          id: '1',
          name: 'Generic Cola',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Generic Cola',
        );
        final title = SearchNormalization.displayTitle(item);
        expect(title, contains('Generic Cola'));
      });
    });

    group('displaySubtitle', () {
      test('formats nutrition info correctly', () {
        final item = FoodModel(
          id: '1',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
          brandName: 'Coca Cola',
          servingVolumeMl: 355,
        );
        final subtitle = SearchNormalization.displaySubtitle(item);
        expect(subtitle, contains('42'));
        expect(subtitle, contains('kcal'));
        expect(subtitle, contains('355'));
      });

      test('handles missing nutrition gracefully', () {
        final item = FoodModel(
          id: '1',
          name: 'Coke',
          servingSize: 0,
          servingUnit: 'ml',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
        );
        final subtitle = SearchNormalization.displaySubtitle(item);
        expect(subtitle, isNotEmpty);
      });
    });

    group('getLeadingLetter', () {
      test('returns first letter of title', () {
        final item = FoodModel(
          id: '1',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
          brandName: 'Coca Cola',
        );
        final letter = SearchNormalization.getLeadingLetter(item);
        expect(letter, 'C');
      });

      test('handles empty titles', () {
        final item = FoodModel(
          id: '1',
          name: '',
          servingSize: 0,
          servingUnit: 'ml',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          source: 'TEST',
          foodName: '',
        );
        final letter = SearchNormalization.getLeadingLetter(item);
        expect(letter.isNotEmpty, true);
      });
    });
  });

  group('SearchRanking', () {
    group('scoreResult', () {
      test('boosts exact brand match', () {
        final item = FoodModel(
          id: '1',
          name: 'Cola',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Cola',
          brandName: 'Coca Cola',
        );
        final scoreWithMatch = scoreResult(item, 'coca cola');
        final scoreWithoutMatch = scoreResult(item, 'generic drink');
        expect(scoreWithMatch, greaterThan(scoreWithoutMatch));
      });

      test('boosts exact product match', () {
        final itemSprite = FoodModel(
          id: '1',
          name: 'Sprite',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Sprite',
          brandName: 'Coca Cola',
        );
        final itemCoke = FoodModel(
          id: '2',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
        );
        final scoreSprite = scoreResult(itemSprite, 'sprite');
        final scoreCoke = scoreResult(itemCoke, 'sprite');
        expect(scoreSprite, greaterThan(scoreCoke));
      });

      test('boosts items with barcode', () {
        final itemWithBarcode = FoodModel(
          id: '1',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
          barcode: '5000112345670',
        );
        final itemWithoutBarcode = FoodModel(
          id: '2',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
        );
        final scoreWith = scoreResult(itemWithBarcode, 'coke');
        final scoreWithout = scoreResult(itemWithoutBarcode, 'coke');
        expect(scoreWith, greaterThan(scoreWithout));
      });

      test('boosts branded items', () {
        final branded = FoodModel(
          id: '1',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
          isBranded: true,
        );
        final unbranded = FoodModel(
          id: '2',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
          isBranded: false,
        );
        final scoreBranded = scoreResult(branded, 'coke');
        final scoreUnbranded = scoreResult(unbranded, 'coke');
        expect(scoreBranded, greaterThan(scoreUnbranded));
      });

      test('boosts complete nutrition', () {
        final complete = FoodModel(
          id: '1',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 11,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
        );
        final incomplete = FoodModel(
          id: '2',
          name: 'Coke',
          servingSize: 355,
          servingUnit: 'ml',
          calories: 42,
          protein: 0,
          carbs: 0,
          fat: 0,
          source: 'TEST',
          foodName: 'Coke',
        );
        final scoreComplete = scoreResult(complete, 'coke');
        final scoreIncomplete = scoreResult(incomplete, 'coke');
        expect(scoreComplete, greaterThanOrEqualTo(scoreIncomplete));
      });
    });

    group('dedupeResults', () {
      test('removes exact duplicates with same dedup key', () {
        final items = [
          FoodModel(
            id: '1',
            name: 'Coke',
            servingSize: 355,
            servingUnit: 'ml',
            calories: 42,
            protein: 0,
            carbs: 11,
            fat: 0,
            source: 'USDA',
            foodName: 'Coke',
            brandName: 'Coca Cola',
          ),
          FoodModel(
            id: '2',
            name: 'coke',
            servingSize: 355,
            servingUnit: 'ml',
            calories: 42,
            protein: 0,
            carbs: 11,
            fat: 0,
            source: 'OFF',
            foodName: 'coke',
            brandName: 'coca cola',
          ),
        ];
        final result = dedupeResults(items, 'coke');
        expect(result.length, 1);
      });

      test('keeps items with different dedup keys', () {
        final items = [
          FoodModel(
            id: '1',
            name: 'Coke',
            servingSize: 355,
            servingUnit: 'ml',
            calories: 42,
            protein: 0,
            carbs: 11,
            fat: 0,
            source: 'USDA',
            foodName: 'Coke',
            brandName: 'Coca Cola',
          ),
          FoodModel(
            id: '2',
            name: 'Pepsi',
            servingSize: 355,
            servingUnit: 'ml',
            calories: 42,
            protein: 0,
            carbs: 11,
            fat: 0,
            source: 'OFF',
            foodName: 'Pepsi',
            brandName: 'PepsiCo',
          ),
        ];
        final result = dedupeResults(items, 'cola');
        expect(result.length, 2);
      });

      test('keeps barcode as secondary key', () {
        final items = [
          FoodModel(
            id: '1',
            name: 'Coke',
            servingSize: 355,
            servingUnit: 'ml',
            calories: 42,
            protein: 0,
            carbs: 11,
            fat: 0,
            source: 'USDA',
            foodName: 'Coke',
            barcode: '5000112345670',
          ),
          FoodModel(
            id: '2',
            name: 'Coca Cola',
            servingSize: 355,
            servingUnit: 'ml',
            calories: 42,
            protein: 0,
            carbs: 11,
            fat: 0,
            source: 'OFF',
            foodName: 'Coca Cola',
            barcode: '5000112345670',
          ),
        ];
        final result = dedupeResults(items, 'coke');
        expect(result.length, 1);
      });

      test('sorts by score descending', () {
        final items = [
          FoodModel(
            id: '1',
            name: 'Something Else',
            servingSize: 1,
            servingUnit: 'can',
            calories: 1,
            protein: 0,
            carbs: 0,
            fat: 0,
            source: 'TEST',
            foodName: 'Something Else',
            isBranded: false,
          ),
          FoodModel(
            id: '2',
            name: 'Coca Cola',
            servingSize: 355,
            servingUnit: 'ml',
            calories: 42,
            protein: 0,
            carbs: 11,
            fat: 0,
            source: 'TEST',
            foodName: 'Coca Cola',
            isBranded: true,
          ),
        ];
        final result = dedupeResults(items, 'coca cola');
        // Branded Coca Cola should rank higher when searching for "coca cola"
        expect(result.first.isBranded ?? false, true);
      });
    });
  });
}
