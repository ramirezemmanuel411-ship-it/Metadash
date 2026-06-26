import 'package:flutter/material.dart';
import 'package:metadash/services/food_service.dart';
import 'package:metadash/services/food_text_normalizer.dart';
import 'package:metadash/shared/palette.dart';

class FoodDetailPage extends StatefulWidget {
  final Food food;

  const FoodDetailPage({super.key, required this.food});

  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  double _servings = 1.0;

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final calories = (food.calories * _servings).toInt();
    final protein = (food.protein * _servings).toInt();
    final carbs = (food.carbs * _servings).toInt();
    final fat = (food.fat * _servings).toInt();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.accent,
        foregroundColor: context.colors.onPrimary,
        title: const Text('Food Details'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Food Name and Brand
                Text(
                  FoodTextNormalizer.normalize(food.name),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (food.brand != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    FoodTextNormalizer.normalize(food.brand!),
                    style: TextStyle(
                      fontSize: 16,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Source: ${food.source}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Serving Size Control
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SERVING SIZE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (_servings > 0.25) {
                                setState(() => _servings -= 0.25);
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                            color: context.colors.accent,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${_servings.toStringAsFixed(2)} serving${_servings != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${(food.servingSize * _servings).toStringAsFixed(1)}g',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => _servings += 0.25);
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            color: context.colors.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Calories
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CALORIES',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.onPrimary.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      Text(
                        '$calories',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: context.colors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Macronutrients
                Text(
                  'MACRONUTRIENTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _MacroCard(
                  label: 'Protein',
                  value: protein,
                  unit: 'g',
                  color: context.colors.accent,
                ),
                const SizedBox(height: 8),
                _MacroCard(
                  label: 'Carbohydrates',
                  value: carbs,
                  unit: 'g',
                  color: context.colors.accent,
                ),
                const SizedBox(height: 8),
                _MacroCard(
                  label: 'Fat',
                  value: fat,
                  unit: 'g',
                  color: context.colors.accent,
                ),
                const SizedBox(height: 24),

                // Per Serving Info
                Container(
                  decoration: BoxDecoration(
                    color: Palette.lightStone,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PER SERVING (${100}g)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _NutrientRow(
                        label: 'Calories',
                        value: '${food.calories.toInt()}',
                      ),
                      _NutrientRow(
                        label: 'Protein',
                        value: '${food.protein.toInt()}g',
                      ),
                      _NutrientRow(
                        label: 'Carbohydrates',
                        value: '${food.carbs.toInt()}g',
                      ),
                      _NutrientRow(label: 'Fat', value: '${food.fat.toInt()}g'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Add to Log Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Return the food item with servings
                  Navigator.pop(context, {
                    'food': food,
                    'servings': _servings,
                    'calories': calories,
                    'protein': protein,
                    'carbs': carbs,
                    'fat': fat,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add to Log',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final Color color;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            '$value$unit',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final String label;
  final String value;

  const _NutrientRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
