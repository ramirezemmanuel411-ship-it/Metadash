import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import '../../models/reentry_mode_state.dart';
import '../../services/reentry_mode_service.dart';
import '../../services/fat_estimate_calculator.dart';

class ReentryReturnFlowScreen extends StatefulWidget {
  final int userId;

  const ReentryReturnFlowScreen({required this.userId, super.key});

  @override
  State<ReentryReturnFlowScreen> createState() =>
      _ReentryReturnFlowScreenState();
}

class _ReentryReturnFlowScreenState extends State<ReentryReturnFlowScreen> {
  final ReentryModeService _service = ReentryModeService();
  int _currentStep = 0; // 0=weight, 1=questions, 2=results
  double? _currentWeight;
  IntakeDelta? _selectedIntakeDelta;
  ActivityDelta? _selectedActivityDelta;
  ReentryModeState? _reentryState;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReentryState();
  }

  Future<void> _loadReentryState() async {
    final state = await _service.getReentryMode(widget.userId);
    setState(() {
      _reentryState = state;
      if (state?.lastKnownWeight != null) {
        _currentWeight = state!.lastKnownWeight;
      }
    });
  }

  Future<void> _endReentryAndShowResults() async {
    if (_currentWeight == null ||
        _selectedIntakeDelta == null ||
        _selectedActivityDelta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _service.endReentryMode(
        userId: widget.userId,
        returnWeight: _currentWeight!,
        intakeDelta: _selectedIntakeDelta!,
        activityDelta: _selectedActivityDelta!,
      );

      // Move to results step
      setState(() {
        _currentStep = 2;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _resume() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_reentryState == null) {
      return Scaffold(
        backgroundColor: Palette.warmNeutral,
        appBar: AppBar(
          backgroundColor: Palette.warmNeutral,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: _currentStep == 2
            ? const Text('All Set')
            : const Text('Welcome Back'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_currentStep == 0)
            _buildWeightInputStep()
          else if (_currentStep == 1)
            _buildQuestionsStep()
          else
            _buildResultsStep(),
        ],
      ),
    );
  }

  Widget _buildWeightInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s your current weight?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ll use this to estimate your fat change during your break.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black.withValues(alpha: 0.6),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scale Weight (lb)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _currentWeight = double.tryParse(value);
                      });
                    },
                    controller: TextEditingController(
                      text: _currentWeight?.toString() ?? '',
                    ),
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Enter weight',
                      hintStyle: TextStyle(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Palette.forestGreen,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentWeight != null
                  ? Palette.forestGreen
                  : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _currentWeight != null
                ? () {
                    setState(() => _currentStep = 1);
                  }
                : null,
            child: const Text(
              'Next',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A few quick questions',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Help us refine the fat change estimate.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black.withValues(alpha: 0.6),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        // Question 1
        _buildQuestionCard(
          question: 'During your break, did you eat…',
          options: [
            ('Less', IntakeDelta.less),
            ('About the same', IntakeDelta.same),
            ('More', IntakeDelta.more),
          ],
          selectedValue: _selectedIntakeDelta,
          onChanged: (value) {
            setState(() => _selectedIntakeDelta = value as IntakeDelta?);
          },
        ),
        const SizedBox(height: 16),
        // Question 2
        _buildQuestionCard(
          question: 'During your break, were you…',
          options: [
            ('Less active', ActivityDelta.less),
            ('About the same', ActivityDelta.same),
            ('More active', ActivityDelta.more),
          ],
          selectedValue: _selectedActivityDelta,
          onChanged: (value) {
            setState(() => _selectedActivityDelta = value as ActivityDelta?);
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _selectedIntakeDelta != null && _selectedActivityDelta != null
                  ? Palette.forestGreen
                  : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed:
                _selectedIntakeDelta != null && _selectedActivityDelta != null
                ? () => _endReentryAndShowResults()
                : null,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'See Results',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard({
    required String question,
    required List<(String, dynamic)> options,
    required dynamic selectedValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return ClipRRect(
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
                question,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            ...options.asMap().entries.map((entry) {
              int index = entry.key;
              final labelValue = entry.value;
              final label = labelValue.$1;
              final value = labelValue.$2;
              bool isSelected = selectedValue == value;

              return Column(
                children: [
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => onChanged(value),
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          Radio(
                            value: value,
                            groupValue: selectedValue,
                            onChanged: onChanged,
                            fillColor: WidgetStateProperty.all(
                              isSelected ? Palette.forestGreen : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Fat Change Estimate',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FatEstimateCalculator.formatFatEstimate(
                      _reentryState?.fatEstimateLowLb,
                      _reentryState?.fatEstimateHighLb,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We\'ll refine this estimate over the next week as you return to routine.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.6),
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
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
            onPressed: _resume,
            child: const Text(
              'Resume',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
