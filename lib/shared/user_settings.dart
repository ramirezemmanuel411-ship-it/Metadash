import 'package:flutter/material.dart';

class UserSettings {
  // Shared notifier for the user's goal weight in pounds. Null means not set.
  static final ValueNotifier<double?> goalWeight = ValueNotifier<double?>(175.0);

  // Appearance settings
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
}
