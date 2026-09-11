import 'package:intl/intl.dart';
import '../models/memory_model.dart';

class GroundedQA {
  static String answerQuestion(String question, List<Memory> memories) {
    if (memories.isEmpty) {
      return "I couldn't find anything in your memories. Try bursting some thoughts first!";
    }

    final q = question.toLowerCase();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Carry queries
    if (q.contains('carry') || q.contains('take') || q.contains('pack') || q.contains('bring') || q.contains('eduthutu')) {
      final carryMems = memories.where((m) => m.type == 'Carry' || m.category == 'Carry' || m.items.isNotEmpty).toList();
      if (carryMems.isNotEmpty) {
        final items = carryMems.expand((m) => m.items).toSet().toList();
        final places = carryMems.expand((m) => m.places).toSet().toList();
        final placeStr = places.isNotEmpty ? ' for ${places.join(", ")}' : '';
        if (items.isNotEmpty) {
          return "Based on your memories, you scheduled to take ${items.join(" and ")}$placeStr.";
        } else {
          return "You have: \"${carryMems.map((m) => m.title).join("; ")}\"$placeStr.";
        }
      }
    }

    // 2. Shopping / Buy queries
    if (q.contains('buy') || q.contains('shopping') || q.contains('grocery') || q.contains('groceries') || q.contains('vaanga')) {
      final shopMems = memories.where((m) => m.type == 'Shopping' || m.category == 'Shopping').toList();
      if (shopMems.isNotEmpty) {
        final items = shopMems.expand((m) => m.items).toSet().toList();
        if (items.isNotEmpty) {
          return "Your shopping list has: ${items.join(", ")}.";
        }
        return "You planned to buy:\n${shopMems.map((m) => "• ${m.title}").join("\n")}";
      }
    }

    // 3. Money / Return / Pay queries
    if (q.contains('money') || q.contains('return') || q.contains('pay') || q.contains('kadan')) {
      final moneyMems = memories.where((m) =>
          m.title.toLowerCase().contains('money') ||
          m.title.toLowerCase().contains('return') ||
          m.title.toLowerCase().contains('pay') ||
          m.details.toLowerCase().contains('money') ||
          m.details.toLowerCase().contains('return')).toList();
      if (moneyMems.isNotEmpty) {
        return "Regarding payments/returns:\n${moneyMems.map((m) => "• ${m.title} (${m.date ?? 'No date'})").join("\n")}";
      }
    }

    // 4. Today / Upcoming queries
    if (q.contains('today') || q.contains('scheduled') || q.contains('pending') || q.contains('tasks') || q.contains('what to do')) {
      final todayMems = memories.where((m) => m.date == todayStr || (!m.completed && m.category == 'Tasks')).toList();
      if (todayMems.isNotEmpty) {
        return "Here are your scheduled tasks:\n${todayMems.map((m) => "• ${m.title} [${m.category}]").join("\n")}";
      }
    }

    // 5. Specific Person query
    for (final m in memories) {
      for (final p in m.people) {
        if (q.contains(p.toLowerCase())) {
          final personMems = memories.where((mem) =>
              mem.people.any((per) => per.toLowerCase() == p.toLowerCase()) ||
              mem.title.toLowerCase().contains(p.toLowerCase())).toList();
          return "Regarding $p, you saved:\n${personMems.map((mem) => "• ${mem.title} (${mem.category})").join("\n")}";
        }
      }
    }

    // 6. Specific Place query
    for (final m in memories) {
      for (final pl in m.places) {
        if (q.contains(pl.toLowerCase())) {
          final placeMems = memories.where((mem) =>
              mem.places.any((plc) => plc.toLowerCase() == pl.toLowerCase()) ||
              mem.title.toLowerCase().contains(pl.toLowerCase())).toList();
          return "Regarding $pl, you have:\n${placeMems.map((mem) => "• ${mem.title} (${mem.category})").join("\n")}";
        }
      }
    }

    // 7. Project queries
    if (q.contains('project') || q.contains('mindburst') || q.contains('jeevansetu')) {
      final projMems = memories.where((m) => m.projects.isNotEmpty || m.category == 'Projects').toList();
      if (projMems.isNotEmpty) {
        return "You have project notes:\n${projMems.map((m) => "• ${m.title}").join("\n")}";
      }
    }

    // 8. General Keyword Match
    final words = q.split(' ').where((w) => w.length > 2).toList();
    final matching = memories.where((m) {
      final text = '${m.title} ${m.details} ${m.category} ${m.items.join(" ")}'.toLowerCase();
      return words.any((w) => text.contains(w));
    }).take(4).toList();

    if (matching.isNotEmpty) {
      final matchingTitles = matching.map((m) => "• ${m.title} (${m.category})").join("\n");
      return "Here is what I found in your memories:\n\n$matchingTitles";
    }

    return "I couldn't find anything relevant to \"$question\" in your memories.";
  }
}
