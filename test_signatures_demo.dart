#!/usr/bin/env dart

// Demo script to show family signature generation for Coke variants
import 'lib/services/universal_food_deduper.dart';

void main() {
  print('=== FAMILY SIGNATURE TEST ===\n');
  
  final testItems = [
    ('Coca Cola Coke Brand', 'Coca-Cola'),
    ('Coca cola Goût Original', 'coke'),
    ('Original Taste Coke', null),
    ('Original Taste', 'Coca Cola,Coke'),
    ('Sabor Original', 'Coca-Cola'),
    ('Diet Coke', 'Coca-Cola'),
    ('Coke Zero', 'Coca-Cola'),
    ('Transformation', 'TRANSFORMATION FLAVORED MINI COKE'),
  ];
  
  print('Query: "coke"\n');
  print('Item Name | Brand | Family Signature');
  print('-' * 80);
  
  for (final (name, brand) in testItems) {
    final sig = UniversalFoodDeduper.buildFamilyKey(
      name: name,
      brand: brand,
      query: 'coke',
    );
    
    final nameNorm = UniversalFoodDeduper.normalize(name);
    final brandNorm = UniversalFoodDeduper.normalizeBrand(brand, nameNorm);
    
    final variants = UniversalFoodDeduper.extractVariants(nameNorm);
    final coreNorm = UniversalFoodDeduper.inferCoreName(
      nameNorm,
      variants,
      brandNorm: brandNorm,
      queryNorm: 'coke',
    );
    
    print('$name | $brand');
    print('  → nameNorm="$nameNorm"');
    print('  → brandNorm="$brandNorm" | coreNorm="$coreNorm" | diet="${variants.dietType}" | flavor="${variants.flavor}"');
    print('  → SIGNATURE: $sig\n');
  }
  
  print('\n=== FAMILY GROUPING ===\n');
  print('Items with signature "coca-cola|cola|regular|none":');
  for (final (name, brand) in testItems) {
    final sig = UniversalFoodDeduper.buildFamilyKey(
      name: name,
      brand: brand,
      query: 'coke',
    );
    
    if (sig == 'coca-cola|cola|regular|none') {
      print('  ✓ $name (brand: $brand)');
    }
  }
  
  print('\nItems with signature "coca-cola|cola|diet|none":');
  for (final (name, brand) in testItems) {
    final sig = UniversalFoodDeduper.buildFamilyKey(
      name: name,
      brand: brand,
      query: 'coke',
    );
    
    if (sig == 'coca-cola|cola|diet|none') {
      print('  ✓ $name (brand: $brand)');
    }
  }
  
  print('\nItems with signature "coca-cola|cola|zero|none":');
  for (final (name, brand) in testItems) {
    final sig = UniversalFoodDeduper.buildFamilyKey(
      name: name,
      brand: brand,
      query: 'coke',
    );
    
    if (sig == 'coca-cola|cola|zero|none') {
      print('  ✓ $name (brand: $brand)');
    }
  }
}
