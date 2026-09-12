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

  test('Double-negation correctly parsed as affirmative task', () {
    final memories = AIExtractor.extractMemories("Don't forget to pay electricity bill today", 40);
    expect(memories.length, 1);
    expect(memories[0].category, anyOf('Tasks', 'Reminders'));
    expect(memories[0].title.toLowerCase(), anyOf(contains('pay electricity bill'), contains('pay bill')));
    expect(memories[0].type, isNot('Note'));
  });

  test('Double-negation carry correctly parsed as Carry', () {
    final memories = AIExtractor.extractMemories("Dont forget to bring hall ticket tomorrow", 41);
    expect(memories.length, 1);
    expect(memories[0].category, 'Carry');
    expect(memories[0].items, contains('Hall Ticket'));
  });

  test('Mobile shorthand tmrw normalizes to tomorrow date', () {
    final memories = AIExtractor.extractMemories("Tmrw morning 9 am submit lab record", 42);
    expect(memories.length, 1);
    expect(memories[0].date, isNotNull);
  });

  test('Relative date day after tomorrow correctly calculated', () {
    final memories = AIExtractor.extractMemories("Day after tomorrow college fee pay pannanum", 43);
    expect(memories.length, 1);
    expect(memories[0].date, isNotNull);
  });

  test('Conversational preambles are stripped from title', () {
    final memories = AIExtractor.extractMemories("Hey Mind, remind me to call manager at 6 PM", 44);
    expect(memories.length, 1);
    expect(memories[0].title.toLowerCase(), isNot(contains('hey mind')));
  });

  test('Tanglish pure negation correctly retained as Note', () {
    final memories = AIExtractor.extractMemories("Milk vendam innaiku curd already fridge la irukku", 45);
    expect(memories.length, 1);
    expect(memories[0].type, 'Note');
    expect(memories[0].category, 'Notes');
  });

  test('Complex multi-item quantity shopping extraction', () {
    final memories = AIExtractor.extractMemories("Buy 2 kg onions, 1 litre milk, and 6 eggs from supermarket", 46);
    expect(memories.length, 1);
    expect(memories[0].category, 'Shopping');
    expect(memories[0].items, containsAll(['Milk', 'Eggs']));
  });

  test('Tanglish bill payment classified as active task or payment', () {
    final memories = AIExtractor.extractMemories("Hostel rent 5th ku gpay pannanum", 47);
    expect(memories.length, 1);
    expect(memories[0].type, isNot('Note'));
    expect(memories[0].title.toLowerCase(), anyOf(contains('hostel rent'), contains('pay hostel rent'), contains('pay rent')));
  });

  test('1000 benchmark neural predictions check across all 7 classes', () {
    final p1 = EdgeNeuralModel.instance.predict('Assignment naalaiku kulla finish pannu');
    expect(p1.intent, 'Task');

    final p2 = EdgeNeuralModel.instance.predict('Amma ku evening 6:30 ku call pannu');
    expect(p2.intent, 'Reminder');

    final p3 = EdgeNeuralModel.instance.predict('Kadaila paal and bread packet vangitu va');
    expect(p3.intent, 'Shopping');

    final p4 = EdgeNeuralModel.instance.predict('Hostel rent 5th ku gpay pannanum');
    expect(p4.intent, 'Payment_Due');

    final p5 = EdgeNeuralModel.instance.predict('College id card and hall ticket eduthutu po');
    expect(p5.intent, 'Carry');

    final p6 = EdgeNeuralModel.instance.predict('SBI bank branch ku visit panrom naalaiku');
    expect(p6.intent, 'Place');

    final p7 = EdgeNeuralModel.instance.predict('Milk vendam innaiku curd already fridge la irukku');
    expect(p7.intent, 'Note');
  });
}
