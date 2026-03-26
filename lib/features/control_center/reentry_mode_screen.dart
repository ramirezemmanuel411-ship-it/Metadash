import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import '../../models/reentry_mode_state.dart';
import '../../services/reentry_mode_service.dart';
import 'reentry_return_flow_screen.dart';

class ReentryModeScreen extends StatefulWidget {
  const ReentryModeScreen({super.key});

  @override
  State<ReentryModeScreen> createState() => _ReentryModeScreenState();
}

class _ReentryModeScreenState extends State<ReentryModeScreen> {
  final ReentryModeService _service = ReentryModeService();
  ReentryModeState? _reentryState;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadReentryMode();
  }

  Future<void> _loadReentryMode() async {
    // TODO: Get userId from Provider/navigation context
    // For now, assume userId = 1 (update based on your actual user management)
    const userId = 1;
    _userId = userId;

    final state = await _service.getReentryMode(userId);
    setState(() {
      _reentryState = state;
      if (state != null && state.isActive) {
        _startDate = state.startDate;
        _endDate = state.endDate;
      }
      _isLoading = false;
    });
  }

  Future<void> _selectDate({
    required BuildContext context,
    required bool isStartDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Palette.forestGreen,
              secondary: Palette.forestGreen,
              surface: Palette.lightStone,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _startReentryMode() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date')),
      );
      return;
    }

    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      await _service.startReentryMode(
        userId: _userId!,
        startDate: _startDate!,
        endDate: _endDate,
      );

      // Reload state
      await _loadReentryMode();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reentry Mode started')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _endReentryMode() async {
    if (_userId == null) return;

    // Navigate to return flow
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReentryReturnFlowScreen(userId: _userId!),
      ),
    );

    // Reload state after return
    if (result == true && mounted) {
      await _loadReentryMode();
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Palette.warmNeutral,
        appBar: AppBar(
          backgroundColor: Palette.warmNeutral,
          foregroundColor: Colors.black87,
          elevation: 0,
          title: const Text('Reentry Mode'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isActive = _reentryState?.isActive ?? false;

    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Reentry Mode'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subtitle
          Text(
            'Taking a break? No problem. Pause tracking now and pick up smoothly later.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Palette.lightStone,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reentry Mode:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                ...<String>[
                  'Pauses calorie targets and goal adjustments',
                  'Ignores weight spikes during your break',
                  'You can still log steps/workouts/food (optional)',
                  'When you return, we\'ll estimate fat change and refine it over the next week',
                ].map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withValues(alpha: 0.6),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Schedule card (shown when not active or if editing)
          if (!isActive) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Palette.lightStone,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Text(
                        'Schedule',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _buildDateRow(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: () =>
                          _selectDate(context: context, isStartDate: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    _buildDateRow(
                      label: 'End Date',
                      date: _endDate,
                      onTap: () =>
                          _selectDate(context: context, isStartDate: false),
                      isOptional: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Text(
                        'End date is optional. You can end Reentry Mode anytime.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.forestGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _startReentryMode,
                child: const Text(
                  'Start Reentry Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            // Active state display
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Palette.lightStone,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Text(
                        'Current Break',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Started',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _formatDate(_reentryState?.startDate),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Palette.forestGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_reentryState?.endDate != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Divider(
                          height: 1,
                          thickness: 0.5,
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                    if (_reentryState?.endDate != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Planned End',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _formatDate(_reentryState?.endDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Palette.forestGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.forestGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _endReentryMode,
                child: const Text(
                  'End Reentry Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool isOptional = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (isOptional) const SizedBox(height: 2),
                if (isOptional)
                  Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: date != null
                        ? Palette.forestGreen
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.black.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
