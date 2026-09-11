import 'package:flutter_test/flutter_test.dart';
import 'package:mindburst_app/services/ai_extractor.dart';
import 'package:mindburst_app/services/grounded_qa.dart';

void main() {
  test('Go to place extraction', () {
    const text = 'Tomorrow I need to go college';
    final memories = AIExtractor.extractMemories(text, 1);

    expect(memories.length, 1);
    final m = memories[0];
    expect(m.category, anyOf('Reminders', 'Tasks'));
    expect(m.title, 'Go to College');
    expect(m.places, contains('College'));
    expect(m.date, isNotNull);
  });

  test('Wash chore extraction', () {
    const text = 'Today we need to wash the dress';
    final memories = AIExtractor.extractMemories(text, 2);

    expect(memories.length, 1);
    final m = memories[0];
    expect(m.category, 'Reminders');
    expect(m.title, 'Wash dress');
    expect(m.items, contains('Dress'));
  });

  test('Shopping sentence extraction', () {
    const text = 'Buy milk and bread from supermarket';
    final memories = AIExtractor.extractMemories(text, 3);

    expect(memories.length, 1);
    final m = memories[0];
    expect(m.category, 'Shopping');
    expect(m.items, containsAll(['Milk', 'Bread']));
    expect(m.places, contains('Supermarket'));
  });

  test('GroundedQA answers places query specifically', () {
    final memories = AIExtractor.extractMemories('Tomorrow I need to go college', 1);
    final answer = GroundedQA.answerQuestion('what are the places I need to go', memories);

    expect(answer.toLowerCase(), contains('college'));
    expect(answer, contains('here are the places you need to go'));
  });
}
