import 'package:flutter/material.dart';
import './exercise_run_screen.dart';
import './exercise_describe_screen.dart';
import './exercise_manual_screen.dart';
import '../../widgets/exercise_card.dart';

/// Main screen for selecting exercise type to log
class ExerciseMainScreen extends StatefulWidget {
  const ExerciseMainScreen({super.key});

  @override
  State<ExerciseMainScreen> createState() => _ExerciseMainScreenState();
}

class _ExerciseMainScreenState extends State<ExerciseMainScreen> {
  void _navigateToRun() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseRunScreen()),
    );
  }

  void _navigateToWeightLifting() {
    // TODO: Create weight lifting screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Weight lifting coming soon')),
    );
  }

  void _navigateToDescribe() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseDescribeScreen()),
    );
  }

  void _navigateToManual() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseManualScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Exercise'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 12,
            children: [
              ExerciseCard(
                title: 'Run',
                subtitle: 'Running, jogging, sprinting, etc.',
                icon: Icons.directions_run,
                onTap: _navigateToRun,
              ),
              ExerciseCard(
                title: 'Weight Lifting',
                subtitle: 'Machines, free weights, etc.',
                icon: Icons.fitness_center,
                onTap: _navigateToWeightLifting,
              ),
              ExerciseCard(
                title: 'Describe',
                subtitle: 'Write your workout in text',
                icon: Icons.edit,
                badge: '✨ Created by AI',
                onTap: _navigateToDescribe,
              ),
              ExerciseCard(
                title: 'Manual',
                subtitle: 'Enter exactly how many calories you burned',
                icon: Icons.local_fire_department,
                onTap: _navigateToManual,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
