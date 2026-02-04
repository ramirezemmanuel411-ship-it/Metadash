// Helper service for computing scale deltas over ranges
class WeightRecord {
  final DateTime date;
  final double weight;

  WeightRecord({required this.date, required this.weight});
}

class ScaleDeltaResult {
  final double? startWeight;
  final double? endWeight;
  final double? delta;
  final DateTime? startDate;
  final DateTime? endDate;

  ScaleDeltaResult({this.startWeight, this.endWeight, this.delta, this.startDate, this.endDate});

  bool get hasEnoughData => startWeight != null && endWeight != null;
}

DateTime? _cutoffForFilter(String filter, DateTime now) {
  switch (filter) {
    case '1D': return now.subtract(const Duration(days: 1));
    case '1W': return now.subtract(const Duration(days: 7));
    case '1M': return DateTime(now.year, now.month - 1, now.day);
    case '3M': return DateTime(now.year, now.month - 3, now.day);
    case '1Y': return DateTime(now.year - 1, now.month, now.day);
    case 'YTD': return DateTime(now.year, 1, 1);
    case 'ALL': return null;
    // support numeric days like '7D', '14D', '30D', '90D'
    default:
      if (filter.endsWith('D')) {
        final n = int.tryParse(filter.replaceAll('D', ''));
        if (n != null) return now.subtract(Duration(days: n));
      }
      return null;
  }
}

ScaleDeltaResult computeScaleDeltaForRange(List<WeightRecord> records, String filter, {DateTime? now}) {
  return computeDeltaByRange<WeightRecord>(
    records,
    filter,
    (r) => r.date,
    (r) => r.weight,
    now: now,
  );
}

// Generic delta computation for any typed record with date/value selectors
ScaleDeltaResult computeDeltaByRange<T>(
  List<T> items,
  String filter,
  DateTime Function(T) dateSelector,
  double Function(T) valueSelector, {
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  if (items.isEmpty) return ScaleDeltaResult();

  final sorted = List<T>.from(items)..sort((a, b) => dateSelector(a).compareTo(dateSelector(b)));
  final cutoff = _cutoffForFilter(filter, effectiveNow);
  final inRange = cutoff == null
      ? sorted
      : sorted.where((r) => dateSelector(r).isAfter(cutoff) || dateSelector(r).isAtSameMomentAs(cutoff)).toList();

  if (inRange.length < 2) return ScaleDeltaResult();

  final start = inRange.first;
  final end = inRange.last;
  final startW = valueSelector(start);
  final endW = valueSelector(end);
  return ScaleDeltaResult(
    startWeight: startW,
    endWeight: endW,
    delta: endW - startW,
    startDate: dateSelector(start),
    endDate: dateSelector(end),
  );
}
