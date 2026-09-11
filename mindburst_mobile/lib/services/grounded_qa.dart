import '../models/memory_model.dart';

class GroundedQA {
  static String answerQuestion(String question, List<Memory> memories) {
    if (memories.isEmpty) {
      return "I couldn't find anything relevant in your memories.";
    }

    final q = question.toLowerCase();

    // Carry queries
    if (q.contains('carry') || q.contains('take')) {
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

    // Rahul queries
    if (q.contains('rahul')) {
      final rahulMems = memories.where((m) => m.people.any((p) => p.toLowerCase().contains('rahul')) || m.title.toLowerCase().contains('rahul')).toList();
      if (rahulMems.isNotEmpty) {
        return "You saved: ${rahulMems.map((m) => m.title).join(" and ")}.";
      }
    }

    // Projects queries
    if (q.contains('project') || q.contains('mindburst') || q.contains('jeevansetu')) {
      final projMems = memories.where((m) => m.projects.isNotEmpty || m.category == 'Projects').toList();
      if (projMems.isNotEmpty) {
        return "You have project notes: ${projMems.map((m) => m.title).join(", ")}.";
      }
    }

    // General match
    final matchingTitles = memories.take(3).map((m) => "• ${m.title} (${m.category})").join("\n");
    return "Here is what I found in your memories:\n\n$matchingTitles";
  }
}
