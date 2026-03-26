import 'package:flutter/material.dart';
import '../../shared/palette.dart';

class VacationModeScreen extends StatefulWidget {
  const VacationModeScreen({super.key});

  @override
  State<VacationModeScreen> createState() => _VacationModeScreenState();
}

class _VacationModeScreenState extends State<VacationModeScreen> {
  bool _vacationModeEnabled = false;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _resumeManually = false;

  Future<void> _selectDate({
    required BuildContext context,
    required bool isStartDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Vacation Mode'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subtitle
          Text(
            'Pause goal evaluations during breaks from structured tracking.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Description block
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
                  'Vacation Mode temporarily pauses:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                ...['Goal progress evaluations', 'Automatic calorie adjustments', 'Plateau detection', 'Weekly check-ins'].map(
                  (item) {
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
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Your energy model continues running, but goal decisions are held until you return.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.6),
                    height: 1.3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main toggle
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vacation Mode',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _vacationModeEnabled ? 'Currently paused' : 'Not active',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: _vacationModeEnabled,
                        onChanged: (newValue) {
                          setState(() {
                            _vacationModeEnabled = newValue;
                            if (!newValue) {
                              _startDate = null;
                              _endDate = null;
                              _resumeManually = false;
                            }
                          });
                        },
                        activeThumbColor: Palette.forestGreen,
                        activeTrackColor: Palette.forestGreen.withValues(alpha: 0.3),
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Date/Resume options (shown when enabled)
          if (_vacationModeEnabled) ...[
            const SizedBox(height: 16),
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
                        'Vacation Timeline',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // Start Date
                    _buildDateRow(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: () => _selectDate(context: context, isStartDate: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    // End Date
                    _buildDateRow(
                      label: 'End Date',
                      date: _endDate,
                      onTap: () => _selectDate(context: context, isStartDate: false),
                      isOptional: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Resume Manually option
            GestureDetector(
              onTap: () {
                setState(() {
                  _resumeManually = !_resumeManually;
                  if (_resumeManually) {
                    _endDate = null;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resume Manually',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'No end date — resume when ready',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: _resumeManually,
                      onChanged: (value) {
                        setState(() {
                          _resumeManually = value ?? false;
                          if (_resumeManually) {
                            _endDate = null;
                          }
                        });
                      },
                      fillColor: WidgetStateProperty.all(
                        _resumeManually ? Palette.forestGreen : Colors.transparent,
                      ),
                      side: BorderSide(
                        color: _resumeManually
                            ? Palette.forestGreen
                            : Colors.black.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
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
                if (isOptional)
                  const SizedBox(height: 2),
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

