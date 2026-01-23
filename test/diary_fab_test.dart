import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:metadash/main.dart';
import 'package:metadash/features/food_search/food_search_screen.dart';

void main() {
  testWidgets('Diary FAB opens FoodSearchScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Switch to Diary tab by tapping the diary navigation icon
    await tester.tap(find.byIcon(Icons.book_outlined));
    await tester.pumpAndSettle();

    // Tap the Add Food FAB
    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();

    // Verify the FoodSearchScreen is pushed
    expect(find.byType(FoodSearchScreen), findsOneWidget);
  });
}
