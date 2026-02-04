/// AI-generated food estimate from chat or camera
class AiFoodEstimate {
  final String itemName;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final double confidence; // 0.0 to 1.0
  final List<String> assumptions;
  final String? rawInput; // User's original prompt

  AiFoodEstimate({
    required this.itemName,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.confidence,
    required this.assumptions,
    this.rawInput,
  });

  factory AiFoodEstimate.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value, {int fallback = 0}) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is double) return value.round();
      return int.tryParse(value.toString()) ?? fallback;
    }

    double toDouble(dynamic value, {double fallback = 0.8}) {
      if (value == null) return fallback;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? fallback;
    }

    return AiFoodEstimate(
      itemName: json['item_name'] ?? json['itemName'] ?? 'Unknown food',
      calories: toInt(json['calories']),
      proteinG: toInt(json['protein_g'] ?? json['proteinG']),
      carbsG: toInt(json['carbs_g'] ?? json['carbsG']),
      fatG: toInt(json['fat_g'] ?? json['fatG']),
      confidence: toDouble(json['confidence']),
      assumptions: json['assumptions'] != null
          ? List<String>.from(json['assumptions'])
          : [],
      rawInput: json['raw_input'] ?? json['rawInput'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_name': itemName,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'confidence': confidence,
      'assumptions': assumptions,
      'raw_input': rawInput,
    };
  }
}
