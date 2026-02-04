import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/ai_food_estimate.dart';

/// AI service for exercise parsing and food estimation
/// Uses Groq (free tier) with OpenAI fallback
class AiService {
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _openaiApiUrl = 'https://api.openai.com/v1/chat/completions';
  
  final String? _groqApiKey;
  final String? _openaiApiKey;

  AiService()
      : _groqApiKey = dotenv.env['GROQ_API_KEY'],
        _openaiApiKey = dotenv.env['OPENAI_API_KEY'];

  bool get hasGroqKey => _groqApiKey != null && _groqApiKey.isNotEmpty;
  bool get hasOpenAiKey => _openaiApiKey != null && _openaiApiKey.isNotEmpty;
  bool get hasAnyKey => hasGroqKey || hasOpenAiKey;

  /// Parse exercise description (e.g., "ran 5k in 30 mins")
  /// Returns: {duration: 30, intensity: 'medium', calories: 350, type: 'run'}
  Future<Map<String, dynamic>> parseExerciseDescription(String description) async {
    final prompt = '''
Parse this exercise description and return ONLY valid JSON (no markdown, no explanations):

User input: "$description"

Return format:
{
  "type": "run|weightlifting|manual|described",
  "duration_minutes": <number>,
  "intensity": "low|medium|high",
  "estimated_calories": <number>,
  "confidence": <0.0-1.0>
}

Rules:
- Estimate calories based on type, duration, intensity
- Default intensity: "medium" if unclear
- If no duration given, estimate from description or return 30
- Return valid JSON only
''';

    try {
      final result = await _callAi(prompt, model: 'llama-3.1-8b-instant');
      return jsonDecode(result);
    } catch (e) {
      // Fallback to basic regex parsing
      return _fallbackExerciseParsing(description);
    }
  }

  /// Estimate food macros from chat input (e.g., "large pepperoni pizza")
  Future<AiFoodEstimate> estimateFoodFromChat(String userInput) async {
    final prompt = '''
You are a nutrition expert. Estimate nutritional values for this food/meal description.

IMPORTANT GUIDELINES:
- If multiple items are listed (e.g., "ribeye with potato, salad, rolls, coke"), sum up ALL items
- For restaurant meals, account for added butter, oil, and generous portions
- Restaurant entrees typically range 700-1500+ calories EACH before sides
- Bread rolls: ~150 cal each
- Baked potato with toppings: 300-400 cal
- Salad with dressing: 150-300 cal
- Regular soda (20 oz): 250 cal
- Large ribeye (16 oz): 1100+ cal

User input: "$userInput"

Return ONLY this JSON format (no markdown, no explanations):
{
  "item_name": "<short meal description>",
  "calories": <total calories for ENTIRE meal>,
  "protein_g": <total grams>,
  "carbs_g": <total grams>,
  "fat_g": <total grams>,
  "confidence": <0.7-0.9>,
  "assumptions": ["List each item counted", "Portion size notes"]
}
''';

    try {
      final result = await _callAi(prompt, model: 'llama-3.1-8b-instant');
      final parsed = _parseJsonSafely(result);
      if (parsed != null) {
        return AiFoodEstimate.fromJson({
          ...parsed,
          'raw_input': userInput,
        });
      }

      // Fallback if parsing fails
      return AiFoodEstimate.fromJson({
        'item_name': userInput.isEmpty ? 'Unknown food' : userInput,
        'calories': 0,
        'protein_g': 0,
        'carbs_g': 0,
        'fat_g': 0,
        'confidence': 0.2,
        'assumptions': ['AI response was not valid JSON. Estimate unavailable.'],
        'raw_input': userInput,
      });
    } catch (e) {
      throw Exception('Failed to estimate food: $e');
    }
  }

  /// Estimate food macros from image using vision model
  /// Optionally includes user description for better accuracy
  Future<AiFoodEstimate> estimateFoodFromImage(
    File imageFile, {
    String? userDescription,
  }) async {
    if (!hasOpenAiKey) {
      throw Exception('OpenAI API key required for image analysis. Add OPENAI_API_KEY to .env');
    }

    try {
      // Read and encode image to base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Build prompt with optional user description
      String promptText = '''Analyze this food image and estimate nutritional values.''';
      
      if (userDescription != null && userDescription.isNotEmpty) {
        promptText += '''\n
User says: "$userDescription"

Use this description to improve accuracy. If the image and description don't match, trust the image but consider portion details from the description.''';
      }

      promptText += '''

IMPORTANT GUIDELINES:
- Identify ALL visible food items in the image
- For restaurant/plated meals, account for oils, butter, and standard portions
- If multiple items visible, sum up ALL items
- Be realistic about portion sizes shown
- Restaurant entrees typically range 700-1500+ calories EACH
- Account for toppings, sauces, and garnishes

Return ONLY this JSON format (no markdown, no explanations):
{
  "item_name": "<brief description of food(s)>",
  "calories": <total calories>,
  "protein_g": <total grams>,
  "carbs_g": <total grams>,
  "fat_g": <total grams>,
  "confidence": <0.5-0.8 for images>,
  "assumptions": ["List each item identified", "Portion size estimates", "Cooking method assumptions"]
}''';

      final response = await http.post(
        Uri.parse(_openaiApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openaiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': promptText,
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'max_tokens': 500,
          'temperature': 0.3,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenAI Vision API error: ${response.statusCode} ${response.body}');
      }

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'].trim();
      
      final parsed = _parseJsonSafely(content);
      if (parsed != null) {
        return AiFoodEstimate.fromJson({
          ...parsed,
          'raw_input': userDescription ?? 'Image analysis',
        });
      }

      // Fallback
      return AiFoodEstimate.fromJson({
        'item_name': 'Unknown food (image)',
        'calories': 0,
        'protein_g': 0,
        'carbs_g': 0,
        'fat_g': 0,
        'confidence': 0.2,
        'assumptions': ['AI could not analyze image. Please try again.'],
        'raw_input': userDescription ?? 'Image analysis failed',
      });
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }

  /// Extract JSON from model response (handles code fences and extra text)
  Map<String, dynamic>? _parseJsonSafely(String text) {
    var trimmed = text.trim();

    // Strip ```json ... ``` or ``` ... ``` fences
    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
        .firstMatch(trimmed);
    if (fenceMatch != null) {
      trimmed = fenceMatch.group(1)!.trim();
    }

    // Try direct decode first
    try {
      final direct = jsonDecode(trimmed);
      if (direct is Map<String, dynamic>) return direct;
    } catch (_) {}

    // Extract first balanced JSON object
    final extracted = _extractBalancedJson(trimmed);
    if (extracted == null) return null;

    try {
      final decoded = jsonDecode(extracted);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    return null;
  }

  String? _extractBalancedJson(String text) {
    int depth = 0;
    int start = -1;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (ch == '}') {
        if (depth > 0) depth--;
        if (depth == 0 && start != -1) {
          return text.substring(start, i + 1);
        }
      }
    }
    return null;
  }

  /// Core AI API caller with Groq → OpenAI fallback
  Future<String> _callAi(String prompt, {String? model}) async {
    if (!hasAnyKey) {
      throw Exception('No AI API keys configured. Add GROQ_API_KEY or OPENAI_API_KEY to .env file');
    }

    // Try Groq first (free tier)
    if (hasGroqKey) {
      try {
        return await _callGroq(prompt, model: model ?? 'llama-3.1-8b-instant');
      } catch (e) {
        print('Groq failed, trying OpenAI fallback: $e');
        if (!hasOpenAiKey) rethrow;
      }
    }

    // Fallback to OpenAI
    if (hasOpenAiKey) {
      return await _callOpenAi(prompt, model: model ?? 'gpt-4o-mini');
    }

    throw Exception('All AI providers failed');
  }

  Future<String> _callGroq(String prompt, {required String model}) async {
    final response = await http.post(
      Uri.parse(_groqApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqApiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3, // Lower temperature for more consistent JSON
        'max_tokens': 500,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'].trim();
  }

  Future<String> _callOpenAi(String prompt, {required String model}) async {
    final response = await http.post(
      Uri.parse(_openaiApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiApiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
        'max_tokens': 500,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'].trim();
  }

  /// Fallback regex-based exercise parsing (no AI needed)
  Map<String, dynamic> _fallbackExerciseParsing(String description) {
    final lower = description.toLowerCase();
    
    // Extract duration
    final durationMatch = RegExp(r'(\d+)\s*(min|minute|minutes|hrs?|hours?)').firstMatch(lower);
    int duration = 30;
    if (durationMatch != null) {
      duration = int.parse(durationMatch.group(1)!);
      if (durationMatch.group(2)!.contains('h')) duration *= 60;
    }

    // Determine type
    String type = 'described';
    if (lower.contains('run') || lower.contains('jog')) {
      type = 'run';
    } else if (lower.contains('lift') || lower.contains('weight')) type = 'weightlifting';
    else if (lower.contains('walk')) type = 'run'; // Treat walking as running

    // Estimate intensity
    String intensity = 'medium';
    if (lower.contains('light') || lower.contains('easy')) {
      intensity = 'low';
    } else if (lower.contains('hard') || lower.contains('intense') || lower.contains('high')) intensity = 'high';

    // Rough calorie estimation
    final intensityMultiplier = intensity == 'low' ? 0.7 : intensity == 'high' ? 1.3 : 1.0;
    final baseCalories = type == 'run' ? 10 : type == 'weightlifting' ? 5 : 7;
    final estimatedCalories = (duration * baseCalories * intensityMultiplier).round();

    return {
      'type': type,
      'duration_minutes': duration,
      'intensity': intensity,
      'estimated_calories': estimatedCalories,
      'confidence': 0.6, // Lower confidence for regex-based parsing
    };
  }
}
