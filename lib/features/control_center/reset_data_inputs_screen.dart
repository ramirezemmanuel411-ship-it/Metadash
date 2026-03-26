import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/data_inputs_settings.dart';

class ResetDataInputsScreen extends StatelessWidget {
  const ResetDataInputsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Reset Data & Inputs'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'This will reset your data input settings back to the defaults.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.55),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Palette.lightStone,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: const Text(
              'This only changes your settings. It won’t delete your logs.',
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.35),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final userState = Provider.of<UserState>(context, listen: false);
              final user = userState.currentUser;
              if (user != null) {
                final defaults = DataInputsSettings.defaults(user.id!);
                await userState.db.createOrUpdateDataInputsSettings(defaults);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings reset to defaults.')),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reset Now'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
