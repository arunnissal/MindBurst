import 'package:flutter_test/flutter_test.dart';
import 'package:mindburst_app/services/ai_extractor.dart';

void main() {
  test('Tanglish compound sentence extraction', () {
    const text = 'Tomorrow namma rahul ku money return pananum and college ku resume kondu ponum';
    final memories = AIExtractor.extractMemories(text, 1);

    expect(memories.length, 2);

    // First memory
    final m1 = memories[0];
    expect(m1.category, anyOf('Tasks', 'Reminders'));
    expect(m1.people, contains('Rahul'));
    expect(m1.date, isNotNull);

    // Second memory
    final m2 = memories[1];
    expect(m2.category, 'Carry');
    expect(m2.places, contains('College'));
    expect(m2.items, contains('Resume'));
  });

  test('Shopping sentence extraction', () {
    const text = 'Buy milk and bread from supermarket';
    final memories = AIExtractor.extractMemories(text, 2);

    expect(memories.length, 1);
    final m = memories[0];
    expect(m.category, 'Shopping');
    expect(m.items, containsAll(['Milk', 'Bread']));
    expect(m.places, contains('Supermarket'));
  });
}
