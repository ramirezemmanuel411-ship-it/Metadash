// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../shared/date_utils.dart';
import '../../shared/palette.dart';

class HorizontalDateWheelPicker extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectedDateChanged;

  const HorizontalDateWheelPicker({
    super.key,
    required this.selectedDate,
    required this.onSelectedDateChanged,
  });

  @override
  State<HorizontalDateWheelPicker> createState() => _HorizontalDateWheelPickerState();
}

class _HorizontalDateWheelPickerState extends State<HorizontalDateWheelPicker> {
  late final List<DateTime> _dates;
  late final ScrollController _controller;
  double _itemExtent = 56;
  double _sidePadding = 0;
  int _currentIndex = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    final today = AppDateUtils.normalizeDate(DateTime.now());
    final start = today.subtract(const Duration(days: 365 * 2));
    final end = today.add(const Duration(days: 365 * 2));
    _dates = _buildDateRange(start, end);
    _currentIndex = _dateToIndex(widget.selectedDate);
    _controller = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToIndex(_currentIndex);
    });
  }

  @override
  void didUpdateWidget(covariant HorizontalDateWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!AppDateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      final index = _dateToIndex(widget.selectedDate);
      _animateToIndex(index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<DateTime> _buildDateRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    var current = AppDateUtils.normalizeDate(start);
    final last = AppDateUtils.normalizeDate(end);
    while (!current.isAfter(last)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  int _dateToIndex(DateTime date) {
    final normalized = AppDateUtils.normalizeDate(date);
    final start = _dates.first;
    final diff = normalized.difference(start).inDays;
    return diff.clamp(0, _dates.length - 1);
  }

  DateTime _indexToDate(int index) {
    return _dates[index.clamp(0, _dates.length - 1)];
  }

  void _jumpToIndex(int index) {
    if (!_controller.hasClients) return;
    final offset = index * _itemExtent;
    _controller.jumpTo(offset);
  }

  Future<void> _animateToIndex(int index) async {
    if (!_controller.hasClients) return;
    if (_isAnimating) return;
    _isAnimating = true;
    final offset = index * _itemExtent;
    await _controller.animateTo(
      offset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _isAnimating = false;
  }

  void _onScrollEnd() {
    if (!_controller.hasClients) return;
    final targetIndex = (_controller.offset / _itemExtent).round().clamp(0, _dates.length - 1);
    _animateToIndex(targetIndex);
    _updateSelectedIndex(targetIndex, notify: true);
  }

  void _updateSelectedIndex(int index, {required bool notify}) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    if (notify) {
      widget.onSelectedDateChanged(_indexToDate(index));
    }
  }

  Future<void> _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: _dates.first,
      lastDate: _dates.last,
    );

    if (picked == null) return;
    final index = _dateToIndex(picked);
    _updateSelectedIndex(index, notify: true);
    _animateToIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _itemExtent = constraints.maxWidth / 7;
        _sidePadding = (constraints.maxWidth - _itemExtent) / 2;

        return SizedBox(
          height: 90,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              _onScrollEnd();
              return false;
            },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return ListView.builder(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: _sidePadding),
                  itemExtent: _itemExtent,
                  itemCount: _dates.length,
                  itemBuilder: (context, index) {
                    final date = _dates[index];
                    final isToday = AppDateUtils.isSameDay(date, DateTime.now());
                    final distance = _distanceFromCenter(index, constraints.maxWidth);
                    final style = _styleForDistance(distance);
                    final isCentered = distance.abs() < 0.5;

                    return GestureDetector(
                      onTap: () {
                        if (isCentered) {
                          _openDatePicker();
                        } else {
                          _updateSelectedIndex(index, notify: true);
                          _animateToIndex(index);
                        }
                      },
                      child: Opacity(
                        opacity: style.opacity,
                        child: Transform.scale(
                          scale: style.scale,
                          child: Center(
                            child: Container(
                              width: _itemExtent * 0.88,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isCentered
                                    ? Palette.lightStone.withOpacity(0.95)
                                    : Palette.lightStone.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(isCentered ? 0.28 : 0.18),
                                  width: isCentered ? 1.2 : 1.0,
                                ),
                              ),
                              child: _DateNode(
                                weekday: AppDateUtils.weekdayShort(date),
                                day: AppDateUtils.dayNumber(date),
                                month: AppDateUtils.monthShort(date),
                                isToday: isToday,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  double _distanceFromCenter(int index, double viewportWidth) {
    if (!_controller.hasClients) return (_currentIndex - index).toDouble();
    final centerOffset = _controller.offset + viewportWidth / 2;
    final itemCenter = _sidePadding + index * _itemExtent + _itemExtent / 2;
    return (itemCenter - centerOffset) / _itemExtent;
  }

  _WheelStyle _styleForDistance(double distance) {
    final abs = distance.abs();
    if (abs < 0.5) return const _WheelStyle(scale: 1.0, opacity: 1.0);
    if (abs < 1.5) return const _WheelStyle(scale: 0.96, opacity: 0.70);
    if (abs < 2.5) return const _WheelStyle(scale: 0.92, opacity: 0.45);
    return const _WheelStyle(scale: 0.88, opacity: 0.25);
  }
}

class _DateNode extends StatelessWidget {
  final String weekday;
  final String day;
  final String month;
  final bool isToday;

  const _DateNode({
    required this.weekday,
    required this.day,
    required this.month,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          weekday,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            fontSize: 9,
            color: textTheme.bodySmall?.color?.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: 0),
        Text(
          day,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 0),
        Text(
          month,
          style: textTheme.bodySmall?.copyWith(fontSize: 10, color: textTheme.bodySmall?.color?.withOpacity(0.8)),
        ),
        if (isToday) ...[
          const SizedBox(height: 2),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class _WheelStyle {
  final double scale;
  final double opacity;

  const _WheelStyle({required this.scale, required this.opacity});
}
