import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:metadash/features/diary/diary_screen.dart';

void main() {
  testWidgets('Diary search bar is visible', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          selectedDay: DateTime.now(),
          caloriesConsumed: 0,
          caloriesGoal: 2000,
          proteinConsumed: 0,
          proteinGoal: 150,
          carbsConsumed: 0,
          carbsGoal: 250,
          fatConsumed: 0,
          fatGoal: 70,
          stepsTaken: 0,
          stepsGoal: 8000,
          userState: null,
        ),
      ),
    );

    expect(find.text('Search foods...'), findsOneWidget);
  });
}
