import 'package:flutter/material.dart';
import '../../shared/palette.dart';

class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Privacy & Data'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Manage permissions and data controls.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
