import 'package:flutter/material.dart';
import '../../shared/palette.dart';

class InterfaceWorkflowScreen extends StatelessWidget {
  const InterfaceWorkflowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text(
          'Interface & Workflow',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Customize layout, shortcuts, and logging behavior.',
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
