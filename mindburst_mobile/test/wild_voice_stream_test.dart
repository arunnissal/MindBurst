import 'package:flutter_test/flutter_test.dart';
import 'package:mindburst_app/services/ai_extractor.dart';

void main() {
  group('Wild Voice Stream Stress Tests (Unpunctuated Continuous Speech)', () {
    test('English 4-Intent Single-Breath Wild Voice Stream', () {
      const wildSpeech =
          "hey mind listen so tomorrow morning 9 am i have to submit my compiler lab record "
          "and then call dr ramesh at 11 am for mom appointment "
          "after that pick up 2 kg apples and brown bread from supermarket "
          "and please don't forget to gpay hostel rent before evening";

      final memories = AIExtractor.extractMemories(wildSpeech, 101);

      expect(memories.length, 4, reason: 'Must decompose 4 distinct thoughts from single-breath speech');

      // Clause 1: Task
      final m1 = memories[0];
      expect(m1.category, anyOf('Tasks', 'Projects'));
      expect(m1.title.toLowerCase(), contains('compiler lab record'));
      expect(m1.date, isNotNull);

      // Clause 2: Reminder
      final m2 = memories[1];
      expect(m2.category, 'Reminders');
      expect(m2.title.toLowerCase(), contains('call dr ramesh'));
      expect(m2.time, isNotNull);

      // Clause 3: Shopping
      final m3 = memories[2];
      expect(m3.category, 'Shopping');
      expect(m3.title.toLowerCase(), contains('buy'));

      // Clause 4: Payment_Due / Task (Double-negation obligation)
      final m4 = memories[3];
      expect(m4.type, isNot('Note'));
      expect(m4.title.toLowerCase(), anyOf(contains('hostel rent'), contains('pay hostel rent'), contains('gpay hostel rent')));
    });

    test('Tanglish 4-Intent Continuous Rambling Stream', () {
      const wildSpeechTanglish =
          "bro listen innaiku evening 6 ku gym polam "
          "apram veetuku varum bodhu kadaila 1 litre paal and muttai vangitu va "
          "apparam maranthu poidaadha mess fee 5th ku kattanum "
          "and college id card marakkama eduthutu po";

      final memories = AIExtractor.extractMemories(wildSpeechTanglish, 102);

      expect(memories.length, 4, reason: 'Must decompose 4 distinct Tanglish thoughts');

      // Clause 1: Reminder / Event
      final m1 = memories[0];
      expect(m1.title.toLowerCase(), contains('gym'));

      // Clause 2: Shopping
      final m2 = memories[1];
      expect(m2.category, 'Shopping');
      expect(m2.title.toLowerCase(), anyOf(contains('buy'), contains('paal')));

      // Clause 3: Payment_Due (Double Negation preserved!)
      final m3 = memories[2];
      expect(m3.type, isNot('Note'));
      expect(m3.title.toLowerCase(), anyOf(contains('mess fee'), contains('pay mess fee')));

      // Clause 4: Carry
      final m4 = memories[3];
      expect(m4.category, 'Carry');
      expect(m4.title.toLowerCase(), anyOf(contains('take'), contains('carry'), contains('college id')));
    });

    test('Errand & Chore 3-Intent Stream with Times', () {
      const stream =
          "clean the kitchen sink today "
          "and wash white shirts before 5 pm "
          "after that reach central railway station by 7 pm";

      final memories = AIExtractor.extractMemories(stream, 103);
      expect(memories.length, 3);

      expect(memories[0].title.toLowerCase(), contains('clean'));
      expect(memories[1].title.toLowerCase(), contains('wash'));
      expect(memories[2].title.toLowerCase(), contains('reach'));
    });
  });
}
