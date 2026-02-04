import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/palette.dart';
import '../../models/ai_food_estimate.dart';
import '../../models/diary_entry_food.dart';
import '../../services/ai_service.dart';
import '../../services/food_text_normalizer.dart';
import '../../providers/user_state.dart';

/// Unified AI screen for food estimation via text, camera, or gallery
class AiChatScreen extends StatefulWidget {
  final UserState userState;

  const AiChatScreen({super.key, required this.userState});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late AiService _aiService;
  bool _serviceInitialized = false;

  AiFoodEstimate? _currentEstimate;
  bool _isLoading = false;
  String? _error;

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
      debugPrint('Error toggling torch: $e');
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

      _cameraController?.dispose();
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
    });

    try {
      final estimate = await _aiService.estimateFoodFromImage(
        _capturedImage!,
        userDescription: description.isNotEmpty ? description : null,
      );

      setState(() {
        _currentEstimate = estimate;
        _isLoading = false;
      });
    } catch (e) {
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
    });

    try {
      final estimate = await _aiService.estimateFoodFromChat(input);
      setState(() {
        _currentEstimate = estimate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
        itemName: _currentEstimate!.itemName,
        calories: _currentEstimate!.calories,
        protein: _currentEstimate!.proteinG,
        carbs: _currentEstimate!.carbsG,
        fat: _currentEstimate!.fatG,
        source: _capturedImage != null ? 'ai_camera' : 'ai_chat',
        confidence: _currentEstimate!.confidence,
        assumptions: _currentEstimate!.assumptions,
        rawInput: _currentEstimate!.rawInput,
      );

      await widget.userState.db.addFoodEntry(entry);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Added to Diary'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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

  @override
  Widget build(BuildContext context) {
    // Show camera overlay
    if (_showCamera) {
      return _buildCameraView();
    }

    // Show main chat interface
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: Palette.warmNeutral,
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
                        color: Palette.lightStone,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: Palette.forestGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'AI Food Assistant',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Type what you ate, snap a photo, or upload from gallery. '
                            'AI will estimate the nutrition for you.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Result card
                    if (_currentEstimate != null)
                      _buildResultCard(_currentEstimate!),

                    if (_isLoading) _buildLoadingCard(),

                    if (_error != null) _buildErrorCard(_error!),
                  ],
                ),
              ),
            ),

            // Input area with photo above text field
            Container(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                24,
              ), // Extra bottom padding for home indicator
              decoration: BoxDecoration(
                color: Palette.lightStone,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Camera button
                  Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: IconButton(
                          onPressed: _isLoading ? null : _openCamera,
                          icon: Icon(
                            Icons.camera_alt,
                            color:
                                _isLoading ? Colors.grey : Palette.vibrantAction,
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
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
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                                              color: Colors.black.withValues(
                                                alpha: 0.7,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
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
                                decoration: InputDecoration(
                                  hintText: _capturedImage != null
                                      ? 'Add comment or Send'
                                      : 'Describe what you ate...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
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
                      // Send button (forest green arrow)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GestureDetector(
                          onTap: _isLoading ? null : _onSendMessage,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _isLoading
                                  ? Colors.grey
                                  : Palette.forestGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward,
                              color: Colors.white,
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
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
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
                              color: Colors.white,
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
                                  color: Colors.white,
                                  width: 4,
                                ),
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
                          // Gallery button
                          IconButton(
                            onPressed: () {
                              _closeCamera();
                              _pickImageFromGallery();
                            },
                            icon: const Icon(
                              Icons.photo_library,
                              color: Colors.white,
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

  Widget _buildResultCard(AiFoodEstimate estimate) {
    final normalizedName = FoodTextNormalizer.normalize(estimate.itemName);
    
    return Card(
      color: Palette.lightStone,
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
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(estimate.confidence * 100).toInt()}% confident',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: estimate.confidence > 0.7
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
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
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroBox(
                    'Protein',
                    '${estimate.proteinG}',
                    'g',
                    Colors.red,
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
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroBox(
                    'Fat',
                    '${estimate.fatG}',
                    'g',
                    Colors.orange,
                  ),
                ),
              ],
            ),

            // Assumptions
            if (estimate.assumptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Assumptions:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              ...estimate.assumptions.map(
                (assumption) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.grey)),
                      Expanded(
                        child: Text(
                          assumption,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Add to Diary button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onAddToDiary,
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
      ),
    );
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
              color: Colors.grey.shade600,
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      color: Palette.lightStone,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(color: Palette.forestGreen),
            const SizedBox(height: 16),
            const Text('Analyzing your food...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(error, style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
        ),
      ),
    );
  }
}
