/// Model for food entries in the diary timeline
class DiaryEntryFood {
  final String id;
  final int userId;
  final DateTime timestamp;
  final String name;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String source; // 'ai_chat', 'ai_camera', 'manual', 'barcode', 'search'
  final double? confidence;
  final List<String>? assumptions;
  final String? rawInput; // Original user input for AI entries

  DiaryEntryFood({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.source,
    this.confidence,
    this.assumptions,
    this.rawInput,
  });

  // Create from AI estimate
  factory DiaryEntryFood.fromAiEstimate({
    required String id,
    required int userId,
    DateTime? timestamp,
    required String itemName,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required String source,
    double? confidence,
    List<String>? assumptions,
    String? rawInput,
  }) {
    return DiaryEntryFood(
      id: id,
      userId: userId,
      timestamp: timestamp ?? DateTime.now(),
      name: itemName,
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      source: source,
      confidence: confidence,
      assumptions: assumptions,
      rawInput: rawInput,
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'name': name,
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
      'source': source,
      'confidence': confidence,
      'assumptions': assumptions?.join('|||'), // Store as delimited string
      'rawInput': rawInput,
    };
  }

  // Create from database map
  factory DiaryEntryFood.fromMap(Map<String, dynamic> map) {
    return DiaryEntryFood(
      id: map['id'] as String,
      userId: map['userId'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      name: map['name'] as String,
      calories: map['calories'] as int,
      proteinG: map['proteinG'] as int,
      carbsG: map['carbsG'] as int,
      fatG: map['fatG'] as int,
      source: map['source'] as String,
      confidence: map['confidence'] as double?,
      assumptions: map['assumptions'] != null
          ? (map['assumptions'] as String).split('|||')
          : null,
      rawInput: map['rawInput'] as String?,
    );
  }

  // Copy with modifications
  DiaryEntryFood copyWith({
    String? id,
    int? userId,
    DateTime? timestamp,
    String? name,
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    String? source,
    double? confidence,
    List<String>? assumptions,
    String? rawInput,
  }) {
    return DiaryEntryFood(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      assumptions: assumptions ?? this.assumptions,
      rawInput: rawInput ?? this.rawInput,
    );
  }

  @override
  String toString() {
    return 'DiaryEntryFood(name: $name, calories: $calories, source: $source)';
  }
}
