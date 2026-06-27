import 'package:flutter/material.dart';
import 'package:metadash/core/providers/food_plate_provider.dart';
import 'package:metadash/core/shared/palette.dart';

/// MacroFactor-style serving keypad shown as a modal bottom sheet. The user
/// dials in a quantity + unit; the live readout rescales by weight using
/// [baseGrams] / [baseCalories], and the chosen amount is reported via
/// [onConfirm]. Shared by the Food Plate and the AI result card.
class ServingNumpad extends StatefulWidget {
  final String initialQty;
  final String initialUnit;
  final List<String> units;
  final int dividerIndex;
  final double? baseGrams;
  final double baseCalories;
  final MetaDashColors colors;
  final void Function(String qty, String unit) onConfirm;

  const ServingNumpad({
    super.key,
    required this.initialQty,
    required this.initialUnit,
    required this.units,
    required this.dividerIndex,
    this.baseGrams,
    this.baseCalories = 0,
    required this.colors,
    required this.onConfirm,
  });

  @override
  State<ServingNumpad> createState() => _ServingNumpadState();
}

class _ServingNumpadState extends State<ServingNumpad> {
  late String _qty;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
    _unit = widget.initialUnit;
  }

  double _gramsForUnit(String u) {
    final w = FoodPlateItem.unitGrams[u.toLowerCase()];
    if (w != null) return w;
    return widget.baseGrams ?? 0;
  }

  double get _qtyNum =>
      double.tryParse(_qty.isEmpty || _qty == '0' ? '1' : _qty) ?? 1;

  double? get _grams {
    final g = _gramsForUnit(_unit);
    return g > 0 ? _qtyNum * g : null;
  }

  double get _liveCal {
    final grams = _grams;
    final base = widget.baseGrams;
    if (grams != null && base != null && base > 0) {
      return widget.baseCalories * grams / base;
    }
    return widget.baseCalories * _qtyNum;
  }

  String _fmtGrams(double g) =>
      '${g >= 10 ? g.round().toString() : g.toStringAsFixed(1)} g';

  void _press(String key) {
    setState(() {
      if (key == '⌫') {
        _qty = _qty.length > 1 ? _qty.substring(0, _qty.length - 1) : '0';
      } else if (key == '.') {
        if (!_qty.contains('.')) _qty += '.';
      } else {
        if (_qty == '0') {
          _qty = key;
        } else if (_qty.length < 8) {
          _qty += key;
        }
      }
    });
  }

  Widget _key(
    String label, {
    bool isDone = false,
    bool isBack = false,
    bool isGray = false,
  }) {
    final c = widget.colors;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isDone
              ? () {
                  widget.onConfirm(
                    _qty == '0' || _qty.isEmpty ? '1' : _qty,
                    _unit,
                  );
                  Navigator.of(context).pop();
                }
              : label.isEmpty
              ? null
              : () => _press(label),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: isDone
                  ? c.accent
                  : isGray || isBack
                  ? c.surfaceVariant
                  : c.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isBack
                  ? Icon(
                      Icons.backspace_outlined,
                      size: 20,
                      color: c.textSecondary,
                    )
                  : label.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: isDone ? 15 : 22,
                        fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                        color: isDone ? c.onPrimary : c.textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Quantity + unit (left) and live calories + grams (right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _qty,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _unit,
                      style: TextStyle(fontSize: 18, color: c.accent),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_liveCal.round()} cal'
                    '${_grams != null ? '  ·  ${_fmtGrams(_grams!)}' : ''}',
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Horizontal unit chips
            SizedBox(
              height: 38,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (int i = 0; i < widget.units.length; i++) ...[
                      if (i == widget.dividerIndex)
                        Container(
                          width: 2,
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: c.accent,
                        ),
                      GestureDetector(
                        onTap: () => setState(() {
                          // Preserve the gram amount when switching units.
                          final og = _gramsForUnit(_unit);
                          final ng = _gramsForUnit(widget.units[i]);
                          final q = double.tryParse(_qty) ?? 1;
                          if (og > 0 && ng > 0 && q > 0) {
                            final newQ = q * og / ng;
                            _qty = newQ == newQ.truncateToDouble()
                                ? newQ.truncate().toString()
                                : newQ.toStringAsFixed(1);
                          }
                          _unit = widget.units[i];
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: widget.units[i] == _unit
                                ? c.accent
                                : c.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.units[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.units[i] == _unit
                                  ? c.onPrimary
                                  : c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Numpad grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _key('1'),
                      _key('2'),
                      _key('3'),
                      _key('⌫', isBack: true),
                    ],
                  ),
                  Row(
                    children: [
                      _key('4'),
                      _key('5'),
                      _key('6'),
                      _key('', isGray: true),
                    ],
                  ),
                  Row(
                    children: [
                      _key('7'),
                      _key('8'),
                      _key('9'),
                      _key('', isGray: true),
                    ],
                  ),
                  Row(
                    children: [
                      _key('.'),
                      _key('0'),
                      _key('', isGray: true),
                      _key('Done', isDone: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
