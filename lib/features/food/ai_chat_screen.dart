import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:metadash/core/logging/app_logger.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/data/repositories/ai_suggestion_repository.dart';
import 'package:metadash/features/food_search/food_plate_screen.dart';
import 'package:metadash/models/ai_food_estimate.dart';
import 'package:metadash/models/ai_router_result.dart';
import 'package:metadash/models/ai_suggestion.dart';
import 'package:metadash/models/diary_entry_food.dart';
import 'package:metadash/providers/food_plate_provider.dart';
import 'package:metadash/providers/user_state.dart';
import 'package:metadash/services/ai_router.dart';
import 'package:metadash/services/ai_service.dart';
import 'package:metadash/services/ai_suggestion_engine.dart';
import 'package:metadash/services/food_text_normalizer.dart';
import 'package:metadash/shared/palette.dart';
import 'package:provider/provider.dart';

/// Unified AI screen for food estimation via text, camera, or gallery
class AiChatScreen extends StatefulWidget {
  final UserState userState;
  final DateTime selectedDay;

  const AiChatScreen({
    super.key,
    required this.userState,
    required this.selectedDay,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late AiService _aiService;
  final AiSuggestionEngine _suggestionEngine = AiSuggestionEngine();
  final AiSuggestionRepository _suggestionRepository = AiSuggestionRepository();
  bool _serviceInitialized = false;

  AiFoodEstimate? _currentEstimate;
  AiSuggestionResponse? _suggestionResponse;
  AiRouterResult? _routerResult;
  int _selectedAlternative = 0;
  bool _isLoading = false;
  String? _error;
  AiRouter? _aiRouter;

  // Camera state
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  bool _showCamera = false;
  bool _torchOn = false;
  File? _capturedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _controller.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _initializeService() {
    if (_serviceInitialized) return;
    try {
      _aiService = AiService();
      _aiRouter = AiRouter(_aiService);
      _serviceInitialized = true;
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize AI service: $e';
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _initializeControllerFuture = _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  void _toggleTorch() async {
    if (_cameraController == null) return;
    try {
      await _cameraController!.setFlashMode(
        _torchOn ? FlashMode.off : FlashMode.torch,
      );
      setState(() => _torchOn = !_torchOn);
    } catch (e) {
      // Silently fail - torch may not be available on all devices
      AppLogger.d('Error toggling torch: $e');
    }
  }

  Future<void> _openCamera() async {
    setState(() {
      _showCamera = true;
      _capturedImage = null;
      _currentEstimate = null;
    });
    await _initializeCamera();
  }

  void _closeCamera() {
    setState(() {
      _showCamera = false;
      _torchOn = false;
    });
    _cameraController?.dispose();
    _cameraController = null;
  }

  Future<void> _capturePhoto() async {
    if (_isLoading || _cameraController == null) return;

    try {
      await _initializeControllerFuture;
      final picture = await _cameraController!.takePicture();
      final imageFile = File(picture.path);

      setState(() {
        _capturedImage = imageFile;
        _currentEstimate = null;
        _showCamera = false;
      });

      await _cameraController?.dispose();
      _cameraController = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
          _currentEstimate = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _analyzeWithImageAndText() async {
    _initializeService();

    if (_error != null || _capturedImage == null) return;

    final description = _controller.text.trim();

    setState(() {
      _isLoading = true;
      _error = null;
      _routerResult = null;
      _currentEstimate = null;
    });

    try {
      // Use AI Router vision mode for structured output
      if (_aiRouter != null) {
        final result = await _aiRouter!.processImage(
          imageFile: _capturedImage!,
          userDescription: description.isNotEmpty ? description : null,
        );
        if (!mounted) return;
        setState(() {
          _routerResult = result;
          _selectedAlternative = 0;
          _isLoading = false;
        });
        return;
      }
      // Fallback to legacy estimate
      final estimate = await _aiService.estimateFoodFromImage(
        _capturedImage!,
        userDescription: description.isNotEmpty ? description : null,
      );
      if (!mounted) return;
      setState(() {
        _currentEstimate = estimate;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _capturedImage = null;
      _currentEstimate = null;
    });
  }

  void _onSendMessage() async {
    _initializeService();

    if (_error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot send message: $_error')));
      return;
    }

    // If there's an image, analyze with image + text
    if (_capturedImage != null) {
      await _analyzeWithImageAndText();
      return;
    }

    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _currentEstimate = null;
      _suggestionResponse = null;
      _routerResult = null;
    });

    try {
      // Build diary context for smarter routing
      final diaryCtx = await _buildDiaryContext();

      // Use AI Router as primary path
      if (_aiRouter != null) {
        final result = await _aiRouter!.processText(
          userText: input,
          diaryContext: diaryCtx,
        );
        if (!mounted) return;
        setState(() {
          _routerResult = result;
          _selectedAlternative = result.bestAlternativeIndex ?? 0;
          _isLoading = false;
        });
        _controller.clear();
        return;
      }

      // Fallback: legacy suggestion engine
      final intent = _suggestionEngine.detectIntent(input);
      if (intent.isSuggestionIntent) {
        final suggestionInput = await _buildSuggestionInput(
          query: input,
          restaurantName: intent.restaurantName,
        );
        final candidates = intent.isRestaurantIntent
            ? await _suggestionRepository.searchRestaurantItems(
                intent.restaurantName ?? input,
              )
            : <FoodModel>[];
        final response = _suggestionEngine.buildSuggestions(
          input: suggestionInput,
          candidates: candidates,
        );
        if (!mounted) return;
        setState(() {
          _suggestionResponse = response;
          _isLoading = false;
        });
        return;
      }

      final estimate = await _aiService.estimateFoodFromChat(input);
      if (!mounted) return;
      setState(() {
        _currentEstimate = estimate;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Build diary context for the AI router (remaining macros/calories).
  Future<Map<String, dynamic>> _buildDiaryContext() async {
    final user = widget.userState.currentUser;
    if (user == null) return {};

    final log = await widget.userState.db.getDailyLogByUserAndDate(
      user.id!,
      widget.selectedDay,
    );
    final foodEntryMaps = await widget.userState.db.getFoodEntriesForDay(
      user.id!,
      widget.selectedDay,
    );

    int foodCalories = 0, foodProtein = 0, foodCarbs = 0, foodFat = 0;
    for (final map in foodEntryMaps) {
      foodCalories += (map['calories'] as int?) ?? 0;
      foodProtein += (map['proteinG'] as int?) ?? 0;
      foodCarbs += (map['carbsG'] as int?) ?? 0;
      foodFat += (map['fatG'] as int?) ?? 0;
    }

    final calConsumed = (log?.caloriesConsumed ?? 0) + foodCalories;
    final pConsumed = (log?.protein ?? 0) + foodProtein;
    final cConsumed = (log?.carbs ?? 0) + foodCarbs;
    final fConsumed = (log?.fat ?? 0) + foodFat;

    final pTarget = user.macroTargets?['protein'] ?? 150;
    final cTarget = user.macroTargets?['carbs'] ?? 250;
    final fTarget = user.macroTargets?['fat'] ?? 73;
    final calGoal = user.dailyCaloricGoal;

    return {
      'caloriesRemaining': calGoal - calConsumed,
      'proteinRemaining': pTarget - pConsumed,
      'carbsRemaining': cTarget - cConsumed,
      'fatRemaining': fTarget - fConsumed,
      'goal': 'lose weight',
    };
  }

  /// Add all entries from a router result to the diary.
  Future<void> _addRouterEntriesToDiary(
    List<AiStructuredFoodEntry> entries,
  ) async {
    final user = widget.userState.currentUser;
    if (user == null || entries.isEmpty) return;
    try {
      final now = _timestampForSelectedDay();
      for (final entry in entries) {
        final diaryEntry = DiaryEntryFood(
          id: '${DateTime.now().millisecondsSinceEpoch}_${entries.indexOf(entry)}',
          userId: user.id!,
          timestamp: now,
          name: entry.name,
          calories: entry.calories,
          proteinG: entry.protein,
          carbsG: entry.carbs,
          fatG: entry.fat,
          source: entry.source,
          serving: entry.serving,
          confidence: _confidenceToDouble(entry.confidence),
          rawInput: _controller.text.trim(),
        );
        await widget.userState.db.addFoodEntry(diaryEntry);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entries.length == 1
                ? '✓ "${entries.first.name}" added to Diary'
                : '✓ ${entries.length} items added to Diary',
          ),
          backgroundColor: context.colors.accent,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _routerResult = null;
        _controller.clear();
        _capturedImage = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    }
  }

  double _confidenceToDouble(String confidence) {
    switch (confidence) {
      case 'high':
        return 0.9;
      case 'low':
        return 0.5;
      default:
        return 0.75;
    }
  }

  Future<AiSuggestionInput> _buildSuggestionInput({
    required String query,
    String? restaurantName,
  }) async {
    final calorieLimit = _parseCalorieLimit(query);
    final user = widget.userState.currentUser;
    if (user == null) {
      return AiSuggestionInput(
        calLeft: 0,
        calorieLimit: calorieLimit,
        pLeft: 0,
        cLeft: 0,
        fLeft: 0,
        pTarget: 0,
        cTarget: 0,
        fTarget: 0,
        query: query,
        restaurantName: restaurantName,
      );
    }

    final log = await widget.userState.db.getDailyLogByUserAndDate(
      user.id!,
      widget.selectedDay,
    );
    final foodEntryMaps = await widget.userState.db.getFoodEntriesForDay(
      user.id!,
      widget.selectedDay,
    );

    int foodCalories = 0;
    int foodProtein = 0;
    int foodCarbs = 0;
    int foodFat = 0;

    for (final map in foodEntryMaps) {
      foodCalories += (map['calories'] as int?) ?? 0;
      foodProtein += (map['proteinG'] as int?) ?? 0;
      foodCarbs += (map['carbsG'] as int?) ?? 0;
      foodFat += (map['fatG'] as int?) ?? 0;
    }

    final caloriesConsumed = (log?.caloriesConsumed ?? 0) + foodCalories;
    final proteinConsumed = (log?.protein ?? 0) + foodProtein;
    final carbsConsumed = (log?.carbs ?? 0) + foodCarbs;
    final fatConsumed = (log?.fat ?? 0) + foodFat;

    final pTarget = user.macroTargets?['protein'] ?? 150;
    final cTarget = user.macroTargets?['carbs'] ?? 250;
    final fTarget = user.macroTargets?['fat'] ?? 73;

    final calLeft = user.dailyCaloricGoal - caloriesConsumed;
    final pLeft = pTarget - proteinConsumed;
    final cLeft = cTarget - carbsConsumed;
    final fLeft = fTarget - fatConsumed;

    return AiSuggestionInput(
      calLeft: calLeft,
      calorieLimit: calorieLimit,
      pLeft: pLeft,
      cLeft: cLeft,
      fLeft: fLeft,
      pTarget: pTarget,
      cTarget: cTarget,
      fTarget: fTarget,
      query: query,
      restaurantName: restaurantName,
    );
  }

  int? _parseCalorieLimit(String query) {
    final pattern = RegExp(
      r'(?:under|below|less than|at most|<=)\s*(\d{2,4})\s*(?:kcal|cal|calories)?',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(query);
    if (match == null) return null;

    final value = int.tryParse(match.group(1) ?? '');
    if (value == null || value <= 0) return null;
    return value;
  }

  DateTime _timestampForSelectedDay() {
    final now = DateTime.now();
    return DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  String? _resolveServingFromAssumptions(List<String> assumptions) {
    for (final assumption in assumptions) {
      final trimmed = assumption.trim();
      if (trimmed.isEmpty) continue;
      if (RegExp(r'\d').hasMatch(trimmed)) {
        return trimmed;
      }
    }
    return null;
  }

  Future<void> _addSuggestionToDiary(Map<String, dynamic> payload) async {
    final user = widget.userState.currentUser;
    if (user == null) return;

    final entry = DiaryEntryFood(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.id!,
      timestamp: _timestampForSelectedDay(),
      name: payload['name'] as String,
      calories: payload['calories'] as int,
      proteinG: payload['proteinG'] as int,
      carbsG: payload['carbsG'] as int,
      fatG: payload['fatG'] as int,
      source: payload['source'] as String,
      serving: payload['serving'] as String?,
      confidence: payload['confidence'] as double?,
      assumptions: (payload['assumptions'] as List?)?.cast<String>(),
      rawInput: _controller.text.trim(),
    );

    await widget.userState.db.addFoodEntry(entry);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ Added to Diary'),
        backgroundColor: context.colors.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onAddToDiary() async {
    if (_currentEstimate == null) return;

    final user = widget.userState.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No user logged in')));
      return;
    }

    try {
      final entry = DiaryEntryFood.fromAiEstimate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.id!,
        timestamp: _timestampForSelectedDay(),
        itemName: _currentEstimate!.itemName,
        calories: _currentEstimate!.calories,
        protein: _currentEstimate!.proteinG,
        carbs: _currentEstimate!.carbsG,
        fat: _currentEstimate!.fatG,
        source: _capturedImage != null ? 'ai_camera' : 'ai_chat',
        serving: _resolveServingFromAssumptions(_currentEstimate!.assumptions),
        confidence: _currentEstimate!.confidence,
        assumptions: _currentEstimate!.assumptions,
        rawInput: _currentEstimate!.rawInput,
      );

      await widget.userState.db.addFoodEntry(entry);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Added to Diary'),
          backgroundColor: context.colors.accent,
          duration: const Duration(seconds: 2),
        ),
      );

      // Clear for next entry
      setState(() {
        _controller.clear();
        _currentEstimate = null;
        _capturedImage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add to diary: $e')));
    }
  }

  /// Stage the current estimate onto the Food Plate so the user can tweak the
  /// serving (and batch it with other items) before logging. AI estimates have
  /// no gram weight, so the plate keypad scales by serving count off these
  /// one-serving base macros.
  void _onAddToPlate() {
    final est = _currentEstimate;
    if (est == null) return;

    context.read<FoodPlateProvider>().add(
      FoodPlateItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        name: est.itemName,
        calories: est.calories,
        proteinG: est.proteinG,
        carbsG: est.carbsG,
        fatG: est.fatG,
        source: _capturedImage != null ? 'ai_camera' : 'ai_chat',
        serving: _resolveServingFromAssumptions(est.assumptions),
        baseCalories: est.calories.toDouble(),
        baseProtein: est.proteinG.toDouble(),
        baseCarbs: est.carbsG.toDouble(),
        baseFat: est.fatG.toDouble(),
      ),
    );

    // No toast — the floating Food Tray button (with its count badge) is the
    // feedback that the item landed on the plate.
    setState(() {
      _controller.clear();
      _currentEstimate = null;
      _capturedImage = null;
    });
  }

  /// Stage all of a router result's entries onto the Food Plate so the user can
  /// tweak servings (and batch them) before logging — the text-logging analogue
  /// of the single-estimate "Add to Food Plate".
  void _addRouterEntriesToPlate(List<AiStructuredFoodEntry> entries) {
    final plate = context.read<FoodPlateProvider>();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      plate.add(
        FoodPlateItem(
          id: '${now}_ai_$i',
          name: e.name,
          calories: e.calories,
          proteinG: e.protein,
          carbsG: e.carbs,
          fatG: e.fat,
          source: 'ai_chat',
          serving: e.serving,
          baseCalories: e.calories.toDouble(),
          baseProtein: e.protein.toDouble(),
          baseCarbs: e.carbs.toDouble(),
          baseFat: e.fat.toDouble(),
          // AI-estimated serving weight (when provided) so the plate keypad
          // shows "cal · g" and converts between units.
          baseGrams: e.grams?.toDouble(),
        ),
      );
    }
    // No toast — the floating Food Tray button (with its count badge) is the
    // feedback that the items landed on the plate.
    setState(() {
      _controller.clear();
      _routerResult = null;
      _currentEstimate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show camera overlay
    if (_showCamera) {
      return _buildCameraView();
    }

    // Show main chat interface
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SizedBox(
          height: double.infinity,
          width: double.infinity,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: context.colors.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'AI Food Assistant',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Type what you ate, snap a photo, or upload from gallery. AI will estimate the nutrition for you.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_routerResult != null)
                        _buildRouterResultCard(_routerResult!),

                      if (_routerResult == null && _suggestionResponse != null)
                        _buildSuggestionResponse(_suggestionResponse!),

                      // Legacy estimate card
                      if (_routerResult == null && _currentEstimate != null)
                        _buildResultCard(_currentEstimate!),

                      if (_isLoading) _buildLoadingCard(),

                      if (_error != null) _buildErrorCard(_error!),
                    ],
                  ),
                ),
              ),

              // Food Tray shortcut — open the plate without leaving the AI
              // screen. Sits just above the input bar (and the keyboard).
              const _FoodTrayButton(),

              // Input area with photo above text field
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.textMuted.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: IconButton(
                        onPressed: _isLoading ? null : _openCamera,
                        icon: Icon(
                          Icons.camera_alt,
                          color: _isLoading
                              ? context.colors.textMuted
                              : context.colors.accent,
                          size: 28,
                        ),
                        tooltip: 'Take photo',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.divider),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Photo preview inside search bar
                            if (_capturedImage != null &&
                                _currentEstimate == null &&
                                !_isLoading)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  8,
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _capturedImage!,
                                        width: 120,
                                        height: 160,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: _removePhoto,
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: context.colors.textMuted
                                                .withValues(alpha: 0.7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: context.colors.onPrimary,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Text field
                            TextField(
                              controller: _controller,
                              style: TextStyle(
                                color: context.colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: _capturedImage != null
                                    ? 'Add comment or Send'
                                    : 'Describe what you ate...',
                                hintStyle: TextStyle(
                                  color: context.colors.textSecondary,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _onSendMessage(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: GestureDetector(
                        onTap: _isLoading ? null : _onSendMessage,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _isLoading
                                ? context.colors.textMuted
                                : context.colors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward,
                            color: context.colors.onPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            _cameraController != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              SizedBox.expand(child: CameraPreview(_cameraController!)),
              // Camera controls overlay
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top bar with close button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _closeCamera,
                            icon: Icon(
                              Icons.close,
                              color: context.colors.onPrimary,
                              size: 32,
                            ),
                            tooltip: 'Close camera',
                          ),
                        ],
                      ),
                    ),
                    // Bottom controls
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Torch button
                          IconButton(
                            onPressed: _toggleTorch,
                            icon: Icon(
                              _torchOn ? Icons.flash_on : Icons.flash_off,
                              color: context.colors.onPrimary,
                              size: 32,
                            ),
                            tooltip: 'Toggle flash',
                          ),
                          const SizedBox(width: 40),
                          // Capture button
                          GestureDetector(
                            onTap: _capturePhoto,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.colors.onPrimary,
                                  width: 4,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.colors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                          // Gallery button
                          IconButton(
                            onPressed: () {
                              _closeCamera();
                              _pickImageFromGallery();
                            },
                            icon: Icon(
                              Icons.photo_library,
                              color: context.colors.onPrimary,
                              size: 32,
                            ),
                            tooltip: 'Choose from gallery',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          return Container(
            color: context.colors.background,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.colors.onPrimary,
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // ── AI Router Result Card ─────────────────────────────────────────────────

  Widget _buildRouterResultCard(AiRouterResult result) {
    final accent = context.colors.accent;
    final surface = context.colors.surface;
    final bool hasAlternatives = result.alternatives.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode badge + headline
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RouterModeBadge(mode: result.mode),
                  const Spacer(),
                  _ConfidenceBadge(confidence: result.confidence),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result.headline,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              if (result.confidenceNote != null) ...[
                const SizedBox(height: 6),
                Text(
                  result.confidenceNote!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Alternatives tab row (restaurant / strategy modes)
        if (hasAlternatives) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: result.alternatives.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final opt = result.alternatives[idx];
                final selected = _selectedAlternative == idx;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAlternative = idx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? accent : surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? accent : context.colors.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (opt.isRecommended)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: selected
                                  ? context.colors.onPrimary
                                  : accent,
                            ),
                          ),
                        Text(
                          opt.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? context.colors.onPrimary
                                : context.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Food entries (primary or selected alternative)
        () {
          final entriesToShow = hasAlternatives
              ? [result.alternatives[_selectedAlternative].entry]
              : result.entries;
          return Column(
            children: entriesToShow
                .map((e) => _RouterEntryRow(entry: e))
                .toList(),
          );
        }(),

        // Alternative reasoning (if selected)
        if (hasAlternatives &&
            _selectedAlternative < result.alternatives.length) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              result.alternatives[_selectedAlternative].reasoning ??
                  'Estimated nutrition values.',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],

        // Detail / assumptions
        if (result.detail != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              result.detail!,
              style: TextStyle(fontSize: 12, color: context.colors.textMuted),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Add to Food Plate — stage to tweak servings before logging
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final entries = hasAlternatives
                  ? [result.alternatives[_selectedAlternative].entry]
                  : result.entries;
              _addRouterEntriesToPlate(entries);
            },
            icon: const Icon(Icons.add_to_photos_outlined, size: 18),
            label: const Text('Add to Food Plate'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Action buttons
        Row(
          children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () {
                  final entries = hasAlternatives
                      ? [result.alternatives[_selectedAlternative].entry]
                      : result.entries;
                  _addRouterEntriesToDiary(entries);
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add to Diary'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: context.colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _routerResult = null;
                  _currentEstimate = null;
                }),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.divider),
                  foregroundColor: context.colors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultCard(AiFoodEstimate estimate) {
    final normalizedName = FoodTextNormalizer.normalize(estimate.itemName);

    return Card(
      color: context.colors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    normalizedName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: estimate.confidence > 0.7
                        ? context.colors.accent.withValues(alpha: 0.2)
                        : context.colors.cta.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(estimate.confidence * 100).toInt()}% confident',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: estimate.confidence > 0.7
                          ? context.colors.accent
                          : context.colors.cta,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Macros grid
            Row(
              children: [
                Expanded(
                  child: _buildMacroBox(
                    'Calories',
                    '${estimate.calories}',
                    'kcal',
                    context.colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroBox(
                    'Protein',
                    '${estimate.proteinG}',
                    'g',
                    context.colors.cta,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMacroBox(
                    'Carbs',
                    '${estimate.carbsG}',
                    'g',
                    context.colors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroBox(
                    'Fat',
                    '${estimate.fatG}',
                    'g',
                    context.colors.cta,
                  ),
                ),
              ],
            ),

            // Assumptions
            if (estimate.assumptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Assumptions:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              ...estimate.assumptions.map(
                (assumption) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                      Expanded(
                        child: Text(
                          assumption,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Add to Food Plate (stage to tweak serving before logging)
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _onAddToPlate,
                icon: const Icon(Icons.add_to_photos_outlined),
                label: const Text('Add to Food Plate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.accent,
                  side: BorderSide(color: context.colors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // Add to Diary button
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onAddToDiary,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  'Add to Diary',
                  style: TextStyle(color: context.colors.onPrimary),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionResponse(AiSuggestionResponse response) {
    return Card(
      color: context.colors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: context.colors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Suggestions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              response.message,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (response.mode == AiSuggestionMode.meal)
              ...response.meals.map(_buildMealSuggestionCard),
            if (response.mode == AiSuggestionMode.singleItem)
              ...response.groups.map(_buildSingleItemGroup),
            if (response.mode == AiSuggestionMode.none)
              Text(
                'You are at or over your target. Consider ultra-low add-ons only.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSuggestionCard(AiMealSuggestion suggestion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.divider),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${suggestion.totals.calories} kcal',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              suggestion.description,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...suggestion.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $item',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _macroLine(suggestion.totals),
              style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () =>
                    _addSuggestionToDiary(suggestion.addActionPayload),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Add to Diary',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleItemGroup(AiSuggestionGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...group.items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.foodName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.serving,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _macroLine(item.totals),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.totals.calories} kcal',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: context.colors.accent),
                    onPressed: () =>
                        _addSuggestionToDiary(item.addActionPayload),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _macroLine(AiSuggestionTotals totals) {
    return 'P ${totals.proteinG}g • C ${totals.carbsG}g • F ${totals.fatG}g';
  }

  Widget _buildMacroBox(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.colors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(color: context.colors.accent),
            const SizedBox(height: 16),
            Text(
              'Analyzing your food...',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ── AI Router support widgets ─────────────────────────────────────────────────

class _RouterModeBadge extends StatelessWidget {
  final AiRouteMode mode;
  const _RouterModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (mode) {
      AiRouteMode.visionFoodEstimate => (
        Icons.camera_alt_outlined,
        const Color(0xFF4C7FA8),
      ),
      AiRouteMode.restaurantOrderHelper => (
        Icons.restaurant_outlined,
        const Color(0xFFEF8C2E),
      ),
      AiRouteMode.mealStrategyHelper => (
        Icons.tips_and_updates_outlined,
        const Color(0xFF2E8B57),
      ),
      AiRouteMode.structuredFoodLogger => (
        Icons.receipt_long_outlined,
        const Color(0xFF2E8B57),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            mode.displayName.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      'high' => const Color(0xFF2E8B57),
      'low' => const Color(0xFFD0021B),
      _ => const Color(0xFFEF8C2E),
    };
    final label = switch (confidence) {
      'high' => 'High confidence',
      'low' => 'Low confidence',
      _ => 'Estimated',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RouterEntryRow extends StatelessWidget {
  final AiStructuredFoodEntry entry;
  const _RouterEntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (entry.brand != null)
                      Text(
                        entry.brand!,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textMuted,
                        ),
                      ),
                    Text(
                      entry.serving,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.calories}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'kcal',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MacroChip(
                label: 'P',
                value: entry.protein,
                color: Palette.macroProtein,
              ),
              const SizedBox(width: 8),
              _MacroChip(
                label: 'C',
                value: entry.carbs,
                color: Palette.macroCarbs,
              ),
              const SizedBox(width: 8),
              _MacroChip(label: 'F', value: entry.fat, color: Palette.macroFat),
              const Spacer(),
              Text(
                'Source: ${entry.source}',
                style: TextStyle(fontSize: 10, color: context.colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            TextSpan(
              text: ' ${value}g',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact Food Tray shortcut shown on the AI screen so a freshly added item
/// can be reviewed on the plate without leaving the chat. Only visible while
/// the plate holds at least one item; rides just above the input bar.
class _FoodTrayButton extends StatelessWidget {
  const _FoodTrayButton();

  @override
  Widget build(BuildContext context) {
    return Consumer<FoodPlateProvider>(
      builder: (context, plate, _) {
        if (plate.isEmpty) return const SizedBox.shrink();
        final colors = context.colors;
        final count = plate.itemCount;
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 16, 10),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FoodPlateScreen()),
              ),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.cta,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.dinner_dining_outlined,
                      color: colors.onPrimary,
                      size: 24,
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.cta, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: colors.cta,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
