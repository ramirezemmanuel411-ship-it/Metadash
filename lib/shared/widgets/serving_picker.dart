import 'package:flutter/material.dart';

import '../palette.dart';

/// A reusable serving-size picker: a tappable quantity + unit field that opens
/// a custom keypad with inline unit chips. Units are gram-mapped, so switching
/// between "1 serving", grams, oz (or ml / fl oz for liquids) preserves the
/// amount and recomputes the quantity — the MacroFactor model.
///
/// [servings] is `[(label, grams), …]` where index 0 is the food's label
/// ("1 serving") size. The picker reports `(quantity, servingIdx, label)` where
/// `quantity` is a multiple of `servings[servingIdx]` — the same contract the
/// host screens already use to scale macros.
class ServingPicker extends StatefulWidget {
  final List<({String label, double? grams})> servings;
  final bool isLiquid;

  /// Calories for one of `servings[0]` (the label serving) — used for the live
  /// preview inside the keypad sheet.
  final double baseCalories;

  final void Function(double quantity, int servingIdx, String label) onChanged;

  const ServingPicker({
    super.key,
    required this.servings,
    required this.baseCalories,
    required this.onChanged,
    this.isLiquid = false,
  });

  @override
  State<ServingPicker> createState() => _ServingPickerState();
}

class _ServingUnit {
  final String label;
  final bool isWeight;
  final double? gramsPerUnit;
  final int? servingIdx;
  const _ServingUnit.weight(this.label, this.gramsPerUnit)
      : isWeight = true,
        servingIdx = null;
  const _ServingUnit.named(this.label, this.servingIdx)
      : isWeight = false,
        gramsPerUnit = null;
}

class _ServingPickerState extends State<ServingPicker> {
  late List<_ServingUnit> _units;
  int _unitIdx = 0;
  int _dividerIndex = -1;
  String _amount = '1';

  double? get _baseGrams =>
      widget.servings.isNotEmpty ? widget.servings[0].grams : null;

  @override
  void initState() {
    super.initState();
    _buildUnits();
    _unitIdx = 0; // first named unit = the food's label ("1 serving") serving
    _amount = '1';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notify();
    });
  }

  void _buildUnits() {
    _units = [];
    final seen = <String>{};
    // Named servings first; servings[0] is the label / FDA serving.
    for (int i = 0; i < widget.servings.length; i++) {
      var lbl = widget.servings[i].label
          .replaceAll(RegExp(r'\s*\(\d+\.?\d*\s*g\)\s*$'), '')
          .trim();
      final isHundredG = RegExp(r'^100\s*g$', caseSensitive: false).hasMatch(lbl);
      // The default (FDA-label) serving expressed only as a weight/volume reads
      // as a generic "serving" — its weight is still available via the g / oz units.
      if (i == 0 && _isBareMeasure(lbl)) lbl = 'serving';
      if (lbl.isEmpty || isHundredG || seen.contains(lbl)) continue;
      seen.add(lbl);
      _units.add(_ServingUnit.named(lbl, i));
    }
    final defG = widget.servings.isNotEmpty ? (widget.servings[0].grams ?? 0) : 0;
    if (defG > 0) {
      // The 2–3 units most relevant to this food go first (left of the divider);
      // every other unit is still available, to the right of the divider.
      const all = <(String, double)>[
        ('g', 1.0),
        ('oz', 28.3495),
        ('lb', 453.592),
        ('ml', 1.0),
        ('fl oz', 29.5735),
        ('cup', 236.588),
        ('tbsp', 14.787),
        ('tsp', 4.929),
      ];
      final common = widget.isLiquid
          ? const ['ml', 'fl oz']
          : const ['g', 'oz'];
      for (final c in common) {
        final u = all.firstWhere((e) => e.$1 == c);
        _units.add(_ServingUnit.weight(u.$1, u.$2));
      }
      _dividerIndex = _units.length;
      for (final u in all) {
        if (common.contains(u.$1)) continue;
        _units.add(_ServingUnit.weight(u.$1, u.$2));
      }
    }
    if (_units.isEmpty) _units.add(const _ServingUnit.named('serving', 0));
  }

  bool _isBareMeasure(String s) => RegExp(
        r'^\d+\.?\d*\s*(g|kg|mg|oz|ml|l|fl\.?\s?oz|lb|lbs)$',
        caseSensitive: false,
      ).hasMatch(s.trim());

  double _amt() => double.tryParse(_amount.trim()) ?? 1.0;

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.truncate().toString();
    final isWeight =
        _units.isNotEmpty && _unitIdx < _units.length && _units[_unitIdx].isWeight;
    return v.toStringAsFixed(isWeight ? 1 : 2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _fmtGrams(double g) {
    final s = g >= 10 ? g.round().toString() : g.toStringAsFixed(1);
    return '$s g';
  }

  double? _toGrams(double amt, int unitIdx) {
    if (unitIdx >= _units.length) return null;
    final u = _units[unitIdx];
    if (u.isWeight) return amt * u.gramsPerUnit!;
    final g = widget.servings[u.servingIdx!].grams;
    return g != null ? amt * g : null;
  }

  double _fromGrams(double grams, _ServingUnit u) {
    if (u.isWeight) return grams / u.gramsPerUnit!;
    final g = widget.servings[u.servingIdx!].grams;
    return (g != null && g > 0) ? grams / g : 1.0;
  }

  void _selectUnit(int idx) {
    if (idx == _unitIdx) return;
    final grams = _toGrams(_amt(), _unitIdx);
    final newAmt =
        grams != null ? _fromGrams(grams, _units[idx]).clamp(0.001, 99999.0) : 1.0;
    setState(() {
      _unitIdx = idx;
      _amount = _fmt(newAmt);
    });
    _notify();
  }

  /// Reports `(quantity, servingIdx, label)` using the same conversion the host
  /// screens expect (weight units resolve to multiples of servings[0]).
  void _notify() {
    if (_units.isEmpty || _unitIdx >= _units.length) return;
    final u = _units[_unitIdx];
    final amt = _amt();
    final base = _baseGrams;
    int srvIdx;
    double qty;
    String label;
    if (u.isWeight) {
      final grams = amt * u.gramsPerUnit!;
      srvIdx = 0;
      qty = (base != null && base > 0) ? grams / base : amt;
      label = '${_fmt(amt)} ${u.label}';
    } else {
      srvIdx = u.servingIdx!;
      final selG = widget.servings[srvIdx].grams;
      qty = (base != null && base > 0 && selG != null && selG > 0)
          ? amt * selG / base
          : amt;
      label = u.label;
    }
    widget.onChanged(qty, srvIdx, label);
  }

  /// The total multiplier + grams the host will apply, for the live preview.
  ({double m, double grams}) _preview() {
    if (_units.isEmpty || _unitIdx >= _units.length) return (m: 0, grams: 0);
    final u = _units[_unitIdx];
    final amt = _amt();
    final base = _baseGrams;
    double qty;
    int srvIdx;
    double? grams;
    if (u.isWeight) {
      grams = amt * u.gramsPerUnit!;
      srvIdx = 0;
      qty = (base != null && base > 0) ? grams / base : amt;
    } else {
      srvIdx = u.servingIdx!;
      final selG = widget.servings[srvIdx].grams;
      grams = selG != null ? amt * selG : null;
      qty = (base != null && base > 0 && selG != null && selG > 0)
          ? amt * selG / base
          : amt;
    }
    double srvMult = 1.0;
    if (srvIdx != 0 && srvIdx < widget.servings.length) {
      final selG = widget.servings[srvIdx].grams;
      final defG = widget.servings[0].grams;
      if (selG != null && selG > 0 && defG != null && defG > 0) {
        srvMult = selG / defG;
      }
    }
    return (m: qty * srvMult, grams: grams ?? (qty * (base ?? 0)));
  }

  String _chipLabel(_ServingUnit u) {
    if (u.isWeight) return u.label;
    if (u.label == 'serving') return 'serving';
    final g = widget.servings[u.servingIdx!].grams;
    if (g != null && g > 0) {
      final gs =
          g == g.truncateToDouble() ? g.truncate().toString() : g.toStringAsFixed(1);
      return '${u.label} ($gs g)';
    }
    return u.label;
  }

  void _keyDigit(String d) {
    var t = _amount;
    if (t == '0') t = '';
    if (t.replaceAll('.', '').length >= 6) return;
    setState(() => _amount = t + d);
    _notify();
  }

  void _keyDot() {
    if (_amount.contains('.')) return;
    setState(() => _amount = _amount.isEmpty ? '0.' : '$_amount.');
    _notify();
  }

  void _keyBackspace() {
    if (_amount.isEmpty) return;
    setState(() => _amount = _amount.substring(0, _amount.length - 1));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = colors.accent;
    final selUnit = _unitIdx < _units.length ? _units[_unitIdx] : null;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUANTITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _openKeypad(context),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    _fmt(_amt()),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selUnit?.label ?? '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openKeypad(BuildContext context) {
    final colors = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, sheetSet) {
            void refresh(VoidCallback fn) {
              fn();
              sheetSet(() {});
            }

            final prev = _preview();
            final selUnit = _unitIdx < _units.length ? _units[_unitIdx] : null;

            Widget keyBtn(String label, VoidCallback? onTap,
                {Widget? child, bool isDone = false, bool isGray = false}) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Material(
                    color: isDone
                        ? colors.accent
                        : (isGray ? colors.surfaceVariant : colors.background),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onTap,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        child: child ??
                            Text(label,
                                style: TextStyle(
                                    fontSize: isDone ? 16 : 22,
                                    fontWeight: isDone
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isDone
                                        ? colors.onPrimary
                                        : colors.textPrimary)),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 8, 12, MediaQuery.of(sheetCtx).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmt(_amt()),
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(selUnit?.label ?? '',
                            style: TextStyle(fontSize: 18, color: colors.accent)),
                      ),
                      const Spacer(),
                      Text(
                        '${(widget.baseCalories * prev.m).round()} cal'
                        '${prev.grams > 0 ? '  ·  ${_fmtGrams(prev.grams)}' : ''}',
                        style: TextStyle(fontSize: 13, color: colors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (int i = 0; i < _units.length; i++) ...[
                            if (i == _dividerIndex)
                              Container(
                                width: 2,
                                height: 22,
                                margin: const EdgeInsets.symmetric(horizontal: 10),
                                color: colors.accent,
                              ),
                            GestureDetector(
                              onTap: () => refresh(() => _selectUnit(i)),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: i == _unitIdx
                                      ? colors.accent
                                      : colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  _chipLabel(_units[i]),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: i == _unitIdx
                                        ? colors.onPrimary
                                        : colors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    keyBtn('1', () => refresh(() => _keyDigit('1'))),
                    keyBtn('2', () => refresh(() => _keyDigit('2'))),
                    keyBtn('3', () => refresh(() => _keyDigit('3'))),
                    keyBtn('', () => refresh(_keyBackspace),
                        isGray: true,
                        child: Icon(Icons.backspace_outlined,
                            size: 20, color: colors.textSecondary)),
                  ]),
                  Row(children: [
                    keyBtn('4', () => refresh(() => _keyDigit('4'))),
                    keyBtn('5', () => refresh(() => _keyDigit('5'))),
                    keyBtn('6', () => refresh(() => _keyDigit('6'))),
                    keyBtn('', null, isGray: true),
                  ]),
                  Row(children: [
                    keyBtn('7', () => refresh(() => _keyDigit('7'))),
                    keyBtn('8', () => refresh(() => _keyDigit('8'))),
                    keyBtn('9', () => refresh(() => _keyDigit('9'))),
                    keyBtn('', null, isGray: true),
                  ]),
                  Row(children: [
                    keyBtn('.', () => refresh(_keyDot)),
                    keyBtn('0', () => refresh(() => _keyDigit('0'))),
                    keyBtn('', null, isGray: true),
                    keyBtn('Done', () => Navigator.pop(sheetCtx), isDone: true),
                  ]),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}
