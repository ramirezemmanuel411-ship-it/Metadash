import 'package:intl/intl.dart';

class AppDateUtils {
  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String dayNumber(DateTime date) {
    return DateFormat('d').format(date);
  }

  static String monthShort(DateTime date) {
    return DateFormat('MMM').format(date);
  }

  static String weekdayShort(DateTime date) {
    return DateFormat('EEE').format(date);
  }

  static String fullLabel(DateTime date) {
    return DateFormat('EEE, MMM d').format(date);
  }
}
