import 'package:flutter/foundation.dart';

class UserSettings {
  // Shared notifier for the user's goal weight in pounds. Null means not set.
  static final ValueNotifier<double?> goalWeight = ValueNotifier<double?>(175.0);
}
