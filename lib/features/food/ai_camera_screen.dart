import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../models/ai_food_estimate.dart';
import '../../models/diary_entry_food.dart';
import '../../providers/user_state.dart';
import '../../services/ai_service.dart';
import '../../shared/palette.dart';

class AiCameraScreen extends StatefulWidget {
  final UserState userState;

  const AiCameraScreen({super.key, required this.userState});

  @override
  State<AiCameraScreen> createState() => _AiCameraScreenState();
}

class _AiCameraScreenState extends State<AiCameraScreen> {
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  
  AiService? _aiService;
  bool _isAnalyzing = false;
  bool _showDescriptionInput = false;
  bool _torchOn = false;
  File? _capturedImage;
  AiFoodEstimate? _currentEstimate;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeService();
    _initializeCamera();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      _aiService = AiService();
      if (!_aiService!.hasOpenAiKey) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OpenAI API key required for AI camera. Add OPENAI_API_KEY to .env'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize AI: $e')),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_isAnalyzing || _cameraController == null) return;

    try {
      await _initializeControllerFuture;
      final picture = await _cameraController!.takePicture();
      final imageFile = File(picture.path);
      
      setState(() {
        _capturedImage = imageFile;
        _showDescriptionInput = true;
        _currentEstimate = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
    }
  }

  Future<void> _analyzeWithDescription() async {
    if (_aiService == null || _capturedImage == null) return;

    final description = _descriptionController.text.trim();
    
    setState(() => _isAnalyzing = true);

    try {
      final estimate = await _aiService!.estimateFoodFromImage(
        _capturedImage!,
        userDescription: description.isNotEmpty ? description : null,
      );
      
      if (mounted) {
        setState(() {
          _currentEstimate = estimate;
          _isAnalyzing = false;
          _showDescriptionInput = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _retakePhoto() async {
    setState(() {
      _capturedImage = null;
      _currentEstimate = null;
      _showDescriptionInput = false;
      _descriptionController.clear();
    });
    if (_cameraController != null) {
      await _cameraController!.initialize();
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
      print('Error toggling torch: $e');
    }
  }

  Future<void> _addToDiary() async {
    if (_currentEstimate == null || widget.userState.currentUser == null) return;

    try {
      final entry = DiaryEntryFood(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: widget.userState.currentUser!.id!,
        timestamp: DateTime.now(),
        name: _currentEstimate!.itemName,
        calories: _currentEstimate!.calories,
        proteinG: _currentEstimate!.proteinG,
        carbsG: _currentEstimate!.carbsG,
        fatG: _currentEstimate!.fatG,
        source: 'ai_camera',
        confidence: _currentEstimate!.confidence,
        assumptions: _currentEstimate!.assumptions,
        rawInput: _currentEstimate!.rawInput,
      );

      await widget.userState.db.addFoodEntry(entry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to diary!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Clear the estimate after adding
        setState(() {
          _currentEstimate = null;
          _capturedImage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to diary: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
            
  @override
  Widget build(BuildContext context) {
    // Show camera view
    if (!_showDescriptionInput && _currentEstimate == null) {
      return FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _cameraController != null) {
            return Stack(
              fit: StackFit.expand,
              children: [
                SizedBox.expand(
                  child: CameraPreview(_cameraController!),
                ),
                // Camera overlay with just capture button, no frame or text
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top spacer
                      const Expanded(child: SizedBox()),
                      // Bottom controls
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Torch button
                            IconButton(
                              onPressed: _toggleTorch,
                              icon: Icon(
                                _torchOn ? Icons.flash_on : Icons.flash_off,
                                color: Colors.white,
                                size: 32,
                              ),
                              tooltip: 'Toggle Flashlight',
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
                                  border: Border.all(color: Colors.white, width: 4),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                            // Placeholder for symmetry
                            const SizedBox(width: 48),
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
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          }
        },
      );
    }

    // Show description input after photo capture
    if (_showDescriptionInput && _capturedImage != null) {
      return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap outside
        child: Container(
          color: Palette.warmNeutral,
          child: Column(
            children: [
              // Image preview
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Image.file(
                      _capturedImage!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Description input section with scrolling
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Describe your meal (optional)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Adding details improves accuracy',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g., "Grilled chicken with rice and vegetables"',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(), // Dismiss on done
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isAnalyzing ? null : _retakePhoto,
                              child: const Text('Retake'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isAnalyzing ? null : _analyzeWithDescription,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Palette.vibrantAction,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isAnalyzing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Analyze', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show results
    return Container(
      height: double.infinity,
      width: double.infinity,
      color: Palette.warmNeutral,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image preview
                  if (_capturedImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _capturedImage!,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Estimate results
                  if (_currentEstimate != null) ...[
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _currentEstimate!.itemName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getConfidenceColor(_currentEstimate!.confidence),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${(_currentEstimate!.confidence * 100).toInt()}% confident',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MacroDisplay(
                                  label: 'Calories',
                                  value: '${_currentEstimate!.calories}',
                                  color: Colors.orange,
                                ),
                                _MacroDisplay(
                                  label: 'Protein',
                                  value: '${_currentEstimate!.proteinG}g',
                                  color: Colors.blue,
                                ),
                                _MacroDisplay(
                                  label: 'Carbs',
                                  value: '${_currentEstimate!.carbsG}g',
                                  color: Colors.green,
                                ),
                                _MacroDisplay(
                                  label: 'Fat',
                                  value: '${_currentEstimate!.fatG}g',
                                  color: Colors.red,
                                ),
                              ],
                            ),
                            if (_currentEstimate!.assumptions.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Assumptions:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              ...(_currentEstimate!.assumptions.map(
                                (assumption) => Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 2),
                                  child: Text(
                                    '• $assumption',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _retakePhoto,
                            child: const Text('Retake'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _addToDiary,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add to Diary'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Palette.forestGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}

class _MacroDisplay extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroDisplay({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
