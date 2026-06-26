import 'package:flutter/material.dart';
import 'package:metadash/features/user_selection/create_user_flow.dart';
import 'package:metadash/providers/user_state.dart';
import 'package:metadash/shared/palette.dart';

class UserSelectionScreen extends StatelessWidget {
  final UserState userState;
  const UserSelectionScreen({super.key, required this.userState});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Brand mark ────────────────────────────────────────────────
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  size: 38,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'MetaDash',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your personal metabolic dashboard.\nEstimate fat change, track your TDEE,\nand understand your body.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: colors.textSecondary,
                  height: 1.6,
                ),
              ),

              const Spacer(flex: 3),

              // ── CTA ───────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateUserFlow(userState: userState),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
