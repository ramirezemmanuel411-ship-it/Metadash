// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:metadash/main.dart';

void main() {
  testWidgets('App shows dashboard screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 200));

    // Verify that the initial screen is user selection (no logged-in user).
    expect(find.text('Select User'), findsWidgets);
  });
}
