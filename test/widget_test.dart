// Smoke test for the launch UI.
//
// MyApp's startup runs async platform/DB init (and a splash delay timer) that
// can't complete in a plain widget test, so we test the SplashScreen — the
// first thing the app shows on launch — directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:metadash/splash_screen.dart';
import 'package:metadash/shared/palette.dart';

void main() {
  testWidgets('Splash screen shows the MetaDash wordmark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [MetaDashColors.day]),
        home: const SplashScreen(),
      ),
    );
    // Let the intro animations and the wordmark delay timer complete.
    await tester.pumpAndSettle();

    expect(find.text('MetaDash'), findsOneWidget);
  });
}
