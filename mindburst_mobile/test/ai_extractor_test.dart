import 'package:flutter_test/flutter_test.dart';
import 'package:mindburst_app/services/ai_extractor.dart';
import 'package:mindburst_app/services/grounded_qa.dart';
import 'package:mindburst_app/services/edge_neural_model.dart';

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
    expect(m.category, 'Tasks');
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
    expect(answer.toLowerCase(), contains('here are the places you need to go'));
  });

  test('Time dot reminder extraction does not split and parses time', () {
    const text = 'Remind me at 7.40pm today';
    final memories = AIExtractor.extractMemories(text, 10);

    expect(memories.length, 1);
    final m = memories[0];
    expect(m.category, 'Reminders');
    expect(m.time, '7:40 PM');
    expect(m.date, isNotNull);
    expect(m.title, contains('7:40 PM'));
  });

  test('GroundedQA answers rent & fee query', () {
    final memories = AIExtractor.extractMemories('Pay hostel rent on 5th and pay mess fee', 20);
    final answer = GroundedQA.answerQuestion('when is my rent due', memories);

    expect(answer.toLowerCase(), contains('financial & payment records'));
    expect(answer.toLowerCase(), contains('rent'));
  });

  test('Negation protection does not convert to task or shopping', () {
    final memories = AIExtractor.extractMemories("Don't buy milk today", 30);
    expect(memories.length, 1);
    expect(memories[0].category, 'Notes');
    expect(memories[0].type, 'Note');
    expect(memories[0].title.toLowerCase(), contains("don't buy milk"));
  });

  test('EdgeNeuralModel predicts intent accurately on Tanglish & English', () {
    final pred1 = EdgeNeuralModel.instance.predict('Kadaila paal and bread vangitu va');
    expect(pred1.intent, 'Shopping');
    expect(pred1.confidence, greaterThan(0.60));

    final pred2 = EdgeNeuralModel.instance.predict('Hostel rent 5th ku gpay pannanum');
    expect(pred2.intent, 'Payment_Due');
    expect(pred2.confidence, greaterThan(0.60));

    final pred3 = EdgeNeuralModel.instance.predict('College id card and hall ticket eduthutu po');
    expect(pred3.intent, 'Carry');
    expect(pred3.confidence, greaterThan(0.60));

    final pred4 = EdgeNeuralModel.instance.predict('Amma ku call pannu evening 6:30 ku');
    expect(pred4.intent, 'Reminder');
    expect(pred4.confidence, greaterThan(0.60));
  });
}
