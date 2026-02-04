import 'package:flutter/material.dart';

/// Duration picker with quick-select pills and custom input
class DurationSelector extends StatefulWidget {
  final int? selectedDuration;
  final ValueChanged<int> onChanged;
  final List<int> quickSelectOptions;

  const DurationSelector({
    super.key,
    this.selectedDuration,
    required this.onChanged,
    this.quickSelectOptions = const [15, 30, 60, 90],
  });

  @override
  State<DurationSelector> createState() => _DurationSelectorState();
}

class _DurationSelectorState extends State<DurationSelector> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.selectedDuration?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectQuickOption(int minutes) {
    setState(() {
      _controller.text = minutes.toString();
    });
    widget.onChanged(minutes);
  }

  void _onCustomInput(String value) {
    if (value.isEmpty) {
      widget.onChanged(0);
      return;
    }
    
    final minutes = int.tryParse(value);
    if (minutes != null && minutes > 0) {
      widget.onChanged(minutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Duration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Quick-select pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.quickSelectOptions
              .map((minutes) => _buildQuickSelectPill(minutes))
              .toList(),
        ),
        const SizedBox(height: 16),
        // Custom input
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          onChanged: _onCustomInput,
          decoration: InputDecoration(
            hintText: 'Custom minutes',
            suffixText: 'min',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSelectPill(int minutes) {
    final isSelected = widget.selectedDuration == minutes;
    
    return GestureDetector(
      onTap: () => _selectQuickOption(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : null,
        ),
        child: Text(
          '$minutes min',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
