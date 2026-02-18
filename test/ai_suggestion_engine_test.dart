import 'package:flutter_test/flutter_test.dart';
import 'package:metadash/models/ai_suggestion.dart';
import 'package:metadash/services/ai_suggestion_engine.dart';

void main() {
  final engine = AiSuggestionEngine();

  AiSuggestionInput baseInput({
    required int calLeft,
    required int pLeft,
    required int cLeft,
    required int fLeft,
    int pTarget = 150,
    int cTarget = 250,
    int fTarget = 73,
  }) {
    return AiSuggestionInput(
      calLeft: calLeft,
      pLeft: pLeft,
      cLeft: cLeft,
      fLeft: fLeft,
      pTarget: pTarget,
      cTarget: cTarget,
      fTarget: fTarget,
      query: 'test',
    );
  }

  test('Mode NONE when calories <= 0', () {
    final mode = engine.decideMode(baseInput(
      calLeft: 0,
      pLeft: 10,
      cLeft: 10,
      fLeft: 10,
    ));
    expect(mode, AiSuggestionMode.none);
  });

  test('Mode B when calVeryTight', () {
    final mode = engine.decideMode(baseInput(
      calLeft: 150,
      pLeft: 40,
      cLeft: 40,
      fLeft: 20,
    ));
    expect(mode, AiSuggestionMode.singleItem);
  });

  test('Mode A when calLeft >= 550 and macroOpenCount >= 2', () {
    final mode = engine.decideMode(baseInput(
      calLeft: 600,
      pLeft: 50,
      cLeft: 40,
      fLeft: 5,
    ));
    expect(mode, AiSuggestionMode.meal);
  });

  test('Mode A when calLeft >= 450 and protein urgent', () {
    final mode = engine.decideMode(baseInput(
      calLeft: 480,
      pLeft: 40,
      cLeft: 10,
      fLeft: 5,
    ));
    expect(mode, AiSuggestionMode.meal);
  });

  test('Mode B when calLeft < 450', () {
    final mode = engine.decideMode(baseInput(
      calLeft: 300,
      pLeft: 20,
      cLeft: 20,
      fLeft: 10,
    ));
    expect(mode, AiSuggestionMode.singleItem);
  });

  test('Mode B when macroOpenCount <= 1 even if calories high', () {
    final mode = engine.decideMode(baseInput(
      calLeft: 500,
      pLeft: 5,
      cLeft: 5,
      fLeft: 5,
    ));
    expect(mode, AiSuggestionMode.singleItem);
  });
}
