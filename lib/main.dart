import 'package:flutter/material.dart';
import 'shared/palette.dart';
import 'app_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Palette.forestGreen),
      scaffoldBackgroundColor: Palette.warmNeutral,
    );

    return MaterialApp(
      title: 'Nutrition',
      theme: theme,
      home: const AppShell(),
    );
  }
}
