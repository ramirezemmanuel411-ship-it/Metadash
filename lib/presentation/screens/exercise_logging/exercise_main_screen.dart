import 'package:flutter/material.dart';
import 'package:metadash/data/repositories/exercise_repository.dart';
import 'package:metadash/presentation/screens/exercise_logging/exercise_describe_screen.dart';
import 'package:metadash/presentation/screens/exercise_logging/exercise_manual_screen.dart';
import 'package:metadash/presentation/screens/exercise_logging/exercise_run_screen.dart';
import 'package:metadash/presentation/screens/exercise_logging/exercise_weightlifting_screen.dart';
import 'package:metadash/providers/user_state.dart';
import 'package:metadash/shared/palette.dart';
import 'package:provider/provider.dart';

/// Main screen for selecting exercise type to log
class ExerciseMainScreen extends StatefulWidget {
  const ExerciseMainScreen({super.key});

  @override
  State<ExerciseMainScreen> createState() => _ExerciseMainScreenState();
}

class _ExerciseMainScreenState extends State<ExerciseMainScreen> {
  int _burnedToday = 0;
  bool _loadingBurned = true;

  @override
  void initState() {
    super.initState();
    _loadBurned();
  }

  Future<void> _loadBurned() async {
    final userState = context.read<UserState>();
    final repo = ExerciseRepository(userState: userState);
    final burned = await repo.getTodayCaloriesBurned();
    if (mounted) {
      setState(() {
        _burnedToday = burned;
        _loadingBurned = false;
      });
    }
  }

  void _navigateToRun() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseRunScreen()),
    );
  }

  void _navigateToWeightLifting() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseWeightLiftingScreen()),
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
    final motivational = _burnedToday > 0 ? 'keep it up!' : 'ready to move?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Exercise'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: context.colors.surface.withValues(alpha: 0),
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _HeroHeader(
            burnedToday: _burnedToday,
            loading: _loadingBurned,
            motivational: motivational,
          ),
          const SizedBox(height: 28),
          const _SectionLabel(label: 'TRACK'),
          const SizedBox(height: 8),
          _ActivityCard(
            children: [
              _ActivityRow(
                icon: Icons.directions_run,
                iconColor: const Color(0xFFFF6B35),
                title: 'Cardio',
                subtitle: 'Running, cycling, swimming & more',
                onTap: _navigateToRun,
              ),
              const _RowDivider(),
              _ActivityRow(
                icon: Icons.fitness_center,
                iconColor: const Color(0xFF4C7FA8),
                title: 'Workouts & Sports',
                subtitle: 'Strength, HIIT, sports & more',
                onTap: _navigateToWeightLifting,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel(label: 'LOG'),
          const SizedBox(height: 8),
          _ActivityCard(
            children: [
              _ActivityRow(
                icon: Icons.auto_awesome,
                iconColor: const Color(0xFF9B59B6),
                title: 'Describe',
                subtitle: 'Write your workout in text',
                badge: '✨ AI',
                onTap: _navigateToDescribe,
              ),
              const _RowDivider(),
              _ActivityRow(
                icon: Icons.local_fire_department,
                iconColor: const Color(0xFF2E8B57),
                title: 'Manual',
                subtitle: 'Enter calories directly',
                onTap: _navigateToManual,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero header
// ---------------------------------------------------------------------------

class _HeroHeader extends StatelessWidget {
  final int burnedToday;
  final bool loading;
  final String motivational;

  const _HeroHeader({
    required this.burnedToday,
    required this.loading,
    required this.motivational,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Color(0xFFFF6B35),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              loading
                  ? Container(
                      width: 100,
                      height: 20,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : Text(
                      burnedToday > 0
                          ? '$burnedToday cal burned'
                          : '— cal burned',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
              const SizedBox(height: 3),
              Text(
                'today · $motivational',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: context.colors.textMuted,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card container
// ---------------------------------------------------------------------------

class _ActivityCard extends StatelessWidget {
  final List<Widget> children;
  const _ActivityCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 70,
      color: context.colors.divider,
    );
  }
}

// ---------------------------------------------------------------------------
// Activity row
// ---------------------------------------------------------------------------

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.cta,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.colors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
