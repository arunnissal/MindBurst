import 'package:intl/intl.dart';
import '../models/memory_model.dart';
import 'ai_extractor.dart';

class GroundedQA {
  static String answerQuestion(String question, List<Memory> memories) {
    if (memories.isEmpty) {
      return "I couldn't find any memories saved yet. Type or speak a thought in Burst to start!";
    }

    final q = question.toLowerCase().trim();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 0. Rent, Mess & Monthly Dues Queries ("rent", "mess fee", "vaadagai", "bill")
    if (q.contains('rent') ||
        q.contains('mess') ||
        q.contains('fee') ||
        q.contains('fees') ||
        q.contains('bill') ||
        q.contains('bills') ||
        q.contains('vaadagai') ||
        q.contains('katnum')) {
      final feeMems = memories.where((m) =>
          m.title.toLowerCase().contains('rent') ||
          m.title.toLowerCase().contains('mess') ||
          m.title.toLowerCase().contains('fee') ||
          m.title.toLowerCase().contains('bill') ||
          m.title.toLowerCase().contains('pay') ||
          m.details.toLowerCase().contains('rent') ||
          m.details.toLowerCase().contains('mess') ||
          m.category.toLowerCase().contains('hostel') ||
          m.category.toLowerCase().contains('payment')).toList();

      if (feeMems.isNotEmpty) {
        final lines = <String>[];
        for (final m in feeMems) {
          final dateStr = m.date != null ? ' [${AIExtractor.formatHumanDate(m.date)}]' : '';
          lines.add('• ${m.title}$dateStr');
        }
        return "Here are your financial & payment records:\n\n${lines.join('\n')}\n\nTip: You can customize your recurring Rent & Mess due day anytime in Profile!";
      } else {
        return "You have no pending rent or mess fee notes in your active memories. Check your Profile tab to see or adjust your recurring monthly due dates!";
      }
    }

    // 1. Reminders & Alarms Queries
    if (q.contains('remind') ||
        q.contains('reminder') ||
        q.contains('alarm') ||
        q.contains('alert') ||
        q.contains('maranthuraadha') ||
        q.contains('time')) {
      final remMems = memories.where((m) =>
          m.category == 'Reminders' ||
          m.type == 'Reminder' ||
          m.time != null ||
          m.title.toLowerCase().contains('remind')).toList();

      if (remMems.isNotEmpty) {
        final lines = <String>[];
        for (final m in remMems) {
          final timeStr = m.time != null ? ' at ${m.time}' : '';
          final dateStr = m.date != null ? ' [${AIExtractor.formatHumanDate(m.date)}$timeStr]' : (timeStr.isNotEmpty ? ' [$timeStr]' : '');
          lines.add('• ${m.title}$dateStr');
        }
        return "Here are your scheduled reminders:\n\n${lines.join('\n')}";
      } else {
        return "You don't have any pending reminders scheduled in your memories.";
      }
    }

    // 2. Places & Destinations Queries ("where do I need to go", "places to visit", "enga ponum")
    if (q.contains('place') ||
        q.contains('places') ||
        q.contains('where') ||
        q.contains('go to') ||
        q.contains('going') ||
        q.contains('visit') ||
        q.contains('destination') ||
        q.contains('enga') ||
        q.contains('ponum')) {
      final placeMems = memories.where((m) =>
          m.places.isNotEmpty ||
          m.category == 'Places' ||
          m.title.toLowerCase().contains('go to') ||
          m.title.toLowerCase().contains('go ') ||
          m.title.toLowerCase().contains('visit') ||
          m.details.toLowerCase().contains('go to') ||
          m.details.toLowerCase().contains('visit')).toList();

      if (placeMems.isNotEmpty) {
        final lines = <String>[];
        for (final m in placeMems) {
          final placeStr = m.places.isNotEmpty ? m.places.join(', ') : 'Location';
          final dateStr = m.date != null ? ' (${AIExtractor.formatHumanDate(m.date)})' : '';
          final timeStr = m.time != null ? ' at ${m.time}' : '';
          lines.add('• $placeStr$dateStr$timeStr — ${m.title}');
        }
        return "Here are the places you need to go:\n\n${lines.join('\n')}\n\nTip: You can tap the place badge in Memories to open directly in Google Maps!";
      } else {
        return "You haven't scheduled any places to visit in your memories.";
      }
    }

    // 3. Carry Items Queries ("what should I carry", "what to take", "enna edukanum")
    if (q.contains('carry') ||
        q.contains('take') ||
        q.contains('pack') ||
        q.contains('bring') ||
        q.contains('eduthutu') ||
        q.contains('edukanum')) {
      final carryMems = memories.where((m) =>
          m.type == 'Carry' ||
          m.category == 'Carry' ||
          m.items.isNotEmpty && (m.title.toLowerCase().contains('take') || m.title.toLowerCase().contains('carry'))).toList();

      if (carryMems.isNotEmpty) {
        final items = carryMems.expand((m) => m.items).toSet().toList();
        final places = carryMems.expand((m) => m.places).toSet().toList();
        final placeStr = places.isNotEmpty ? ' for ${places.join(", ")}' : '';

        if (items.isNotEmpty) {
          return "Based on your memories, you need to carry:\n\n• ${items.join("\n• ")}$placeStr";
        } else {
          return "Items to carry:\n\n${carryMems.map((m) => "• ${m.title}").join("\n")}";
        }
      } else {
        return "You don't have any items scheduled to carry.";
      }
    }

    // 4. Shopping & Purchases Queries ("what to buy", "shopping list", "enna vaanganum")
    if (q.contains('buy') ||
        q.contains('shopping') ||
        q.contains('grocery') ||
        q.contains('groceries') ||
        q.contains('vaanga') ||
        q.contains('vaanganum')) {
      final shopMems = memories.where((m) =>
          m.type == 'Shopping' ||
          m.category == 'Shopping' ||
          m.title.toLowerCase().startsWith('buy')).toList();

      if (shopMems.isNotEmpty) {
        final items = shopMems.expand((m) => m.items).toSet().toList();
        if (items.isNotEmpty) {
          return "Here is your shopping list:\n\n• ${items.join("\n• ")}";
        }
        return "Here is what you planned to buy:\n\n${shopMems.map((m) => "• ${m.title}").join("\n")}";
      } else {
        return "Your shopping list is currently empty.";
      }
    }

    // 5. Tasks & Chores Queries ("what tasks", "pending tasks", "what to do", "enna pannanum")
    if (q.contains('task') ||
        q.contains('tasks') ||
        q.contains('todo') ||
        q.contains('chore') ||
        q.contains('pending') ||
        q.contains('pannanum') ||
        q.contains('what to do') ||
        q.contains('work')) {
      final taskMems = memories.where((m) =>
          (m.category == 'Tasks' || m.type == 'Task') && !m.completed).toList();

      if (taskMems.isNotEmpty) {
        final lines = <String>[];
        for (final m in taskMems) {
          final dateStr = m.date != null ? ' (${AIExtractor.formatHumanDate(m.date)})' : '';
          lines.add('• ${m.title}$dateStr');
        }
        return "Here are your pending tasks:\n\n${lines.join('\n')}";
      } else {
        return "You have no pending tasks right now. Great job!";
      }
    }

    // 6. Summary / Daily Briefing ("how does my day look", "summary", "today", "schedule", "inniku")
    if (q.contains('summary') ||
        q.contains('day look') ||
        q.contains('schedule') ||
        q.contains('today') ||
        q.contains('inniku') ||
        q.contains('brief')) {
      final todayMems = memories.where((m) =>
          m.date == todayStr ||
          m.category == 'Reminders' ||
          (!m.completed && m.category == 'Tasks')).toList();

      if (todayMems.isNotEmpty) {
        final rems = todayMems.where((m) => m.category == 'Reminders' || m.time != null).toList();
        final tasks = todayMems.where((m) => m.category == 'Tasks' && !m.completed).toList();
        final places = todayMems.where((m) => m.places.isNotEmpty).toList();

        final buffer = StringBuffer();
        buffer.writeln("Here is your personalized summary:");

        if (rems.isNotEmpty) {
          buffer.writeln("\n⏰ Reminders:");
          for (final r in rems) {
            final t = r.time != null ? ' at ${r.time}' : '';
            buffer.writeln("• ${r.title}$t");
          }
        }

        if (tasks.isNotEmpty) {
          buffer.writeln("\n✓ Tasks:");
          for (final t in tasks) {
            buffer.writeln("• ${t.title}");
          }
        }

        if (places.isNotEmpty) {
          buffer.writeln("\n📍 Destinations:");
          for (final p in places) {
            buffer.writeln("• ${p.places.join(', ')} (${p.title})");
          }
        }

        return buffer.toString().trim();
      } else {
        return "You have no active tasks or reminders scheduled for today.";
      }
    }

    // 7. General Keyword Match across all memories
    final words = q.split(' ').where((w) => w.length > 2).toList();
    final matching = memories.where((m) {
      final text = '${m.title} ${m.details} ${m.category} ${m.items.join(" ")} ${m.places.join(" ")}'.toLowerCase();
      return words.any((w) => text.contains(w));
    }).take(5).toList();

    if (matching.isNotEmpty) {
      final matchingTitles = matching.map((m) {
        final timeStr = m.time != null ? ' at ${m.time}' : '';
        final dateStr = m.date != null ? ' (${AIExtractor.formatHumanDate(m.date)}$timeStr)' : (timeStr.isNotEmpty ? ' ($timeStr)' : '');
        return "• ${m.title}$dateStr [${m.category}]";
      }).join("\n");
      return "Here is what I found in your memories:\n\n$matchingTitles";
    }

    return "I couldn't find anything matching \"$question\" in your saved memories. Try asking about your tasks, reminders, places, or shopping list!";
  }
}
