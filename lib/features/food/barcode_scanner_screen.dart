// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/food_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String)? onBarcodeScanned;

  const BarcodeScannerScreen({super.key, this.onBarcodeScanned});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanning = false;
  bool _torchOn = false;
  bool _hasError = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanning) return; // Prevent multiple simultaneous scans

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final barcodeValue = barcode.rawValue;
      if (barcodeValue != null) {
        _isScanning = true;
        widget.onBarcodeScanned?.call(barcodeValue);
        _isScanning = false;
      }
    }
  }

  void _toggleTorch() {
    setState(() => _torchOn = !_torchOn);
    controller.toggleTorch();
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '123456789',
            labelText: 'Barcode Number',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = textController.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                widget.onBarcodeScanned?.call(barcode);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasError = true);
            });
            return Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera permission required',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() => _hasError = false);
                        await openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Scanner UI overlay - hide when there's an error
        if (!_hasError)
          Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  const Text(
                    'Scan Food Barcode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Position the barcode within the frame',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Spacer(),
                  // Scanning frame
                  Center(
                    child: Container(
                      width: 280,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.greenAccent, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Action buttons at the bottom
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
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
                        // Scanner icon (center)
                        const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white70,
                          size: 48,
                        ),
                        const SizedBox(width: 40),
                        // Manual entry button
                        IconButton(
                          onPressed: _showManualEntryDialog,
                          icon: const Icon(
                            Icons.keyboard,
                            color: Colors.white,
                            size: 32,
                          ),
                          tooltip: 'Enter Manually',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Manual food search dialog
class FoodSearchDialog extends StatefulWidget {
  final Function(Food) onFoodSelected;

  const FoodSearchDialog({
    super.key,
    required this.onFoodSelected,
  });

  @override
  State<FoodSearchDialog> createState() => _FoodSearchDialogState();
}

class _FoodSearchDialogState extends State<FoodSearchDialog> {
  final _searchController = TextEditingController();
  final _foodService = FoodService();
  List<Food> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await _foodService.searchFoods(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search Food'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'e.g., "Chobani yogurt"',
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No foods found'),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final food = _searchResults[index];
                    return ListTile(
                      title: Text(food.name),
                      subtitle: Text('${food.brand} - ${food.calories} cal'),
                      onTap: () => widget.onFoodSelected(food),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
