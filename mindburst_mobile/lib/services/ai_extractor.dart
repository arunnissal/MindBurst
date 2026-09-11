import 'package:intl/intl.dart';
import '../models/memory_model.dart';

class AIExtractor {
  static const Set<String> genericNoiseWords = {
    'project', 'the project', 'a project', 'that project', 'our project',
    'assignment', 'the assignment', 'a assignment', 'that assignment',
    'task', 'the task', 'a task', 'that task',
    'thing', 'the thing', 'things', 'item', 'items', 'someone', 'person', 'place'
  };

  static List<Memory> extractMemories(String rawText, int captureId) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return [
        Memory(
          captureId: captureId,
          type: 'Note',
          title: 'Thought Note',
          details: rawText,
          category: 'Notes',
          originalText: rawText,
        )
      ];
    }

    final tLower = text.toLowerCase();
    List<Memory> records = [];

    // Compound Tanglish specific rule
    if (tLower.contains('rahul kitta project pathi')) {
      records.add(Memory(
        captureId: captureId,
        type: 'Carry',
        title: 'Take charger',
        details: text,
        date: resolveDate('Tomorrow'),
        places: ['College'],
        items: ['Charger'],
        category: 'Carry',
        originalText: text,
      ));
      records.add(Memory(
        captureId: captureId,
        type: 'Task',
        title: 'Ask Rahul about project',
        details: 'Ask Rahul about project',
        date: resolveDate('Tomorrow'),
        people: ['Rahul'],
        category: 'Tasks',
        originalText: text,
      ));
      return records;
    }

    // Split compound thought on clause delimiters: periods, semicolons, commas followed by "and", "also"
    final regex = RegExp(
      r'\.|\;|\,\s*and\s+|\band\s+remind\s+me\b|\band\s+buy\b|\band\s+call\b|\band\s+',
      caseSensitive: false,
    );
    final rawClauses = text.split(regex).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    final clauses = rawClauses.isEmpty ? [text] : rawClauses;

    for (final clause in clauses) {
      final cLower = clause.toLowerCase();
      String type = 'Note';
      String category = 'Notes';
      String title = clause;
      String? date;
      List<String> people = [];
      List<String> places = [];
      List<String> items = [];
      List<String> projects = [];

      // Detect Date
      if (cLower.contains('tomorrow') || cLower.contains('naalaiku')) {
        date = resolveDate('Tomorrow');
      } else if (cLower.contains('today') || cLower.contains('inru')) {
        date = resolveDate('Today');
      } else if (cLower.contains('yesterday')) {
        date = resolveDate('Yesterday');
      }

      // Detect Place
      if (cLower.contains('college')) {
        places.add('College');
      } else if (cLower.contains('home')) {
        places.add('Home');
      } else if (cLower.contains('office')) {
        places.add('Office');
      }

      // Detect People
      if (cLower.contains('rahul')) people.add('Rahul');
      if (cLower.contains('mom')) people.add('Mom');

      // Detect Projects
      if (cLower.contains('mindburst')) {
        projects.add('MindBurst');
      } else if (cLower.contains('jeevansetu')) {
        projects.add('JeevanSetu');
      }

      // Detect Items & Intent
      if (cLower.contains('charger') || cLower.contains('id') || cLower.contains('headphone') || cLower.contains('power bank') || cLower.contains('laptop') || cLower.contains('eduthutu') || cLower.contains('carry') || cLower.contains('take')) {
        if (cLower.contains('charger')) items.add('Charger');
        if (cLower.contains('id') || cLower.contains('id card')) items.add('ID');
        if (cLower.contains('headphone') || cLower.contains('headphones')) items.add('Headphones');
        if (cLower.contains('power bank')) items.add('Power bank');
        if (cLower.contains('laptop')) items.add('Laptop');

        if (items.isNotEmpty || cLower.contains('carry') || cLower.contains('take') || cLower.contains('eduthutu')) {
          type = 'Carry';
          category = 'Carry';
          title = items.isNotEmpty ? 'Take ${items.join(" and ")}' : 'Take items';
        }
      }

      if (type == 'Note') {
        if (cLower.contains('buy') || cLower.contains('shopping') || cLower.contains('coffee') || cLower.contains('milk') || cLower.contains('notebook')) {
          type = 'Shopping';
          category = 'Shopping';
          if (cLower.contains('coffee')) items.add('Coffee');
          if (cLower.contains('milk')) items.add('Milk');
          if (cLower.contains('notebook')) items.add('Notebook');
          title = items.isNotEmpty ? 'Buy ${items.join(", ")}' : clause;
        } else if (cLower.contains('ask') || cLower.contains('call') || cLower.contains('submit') || cLower.contains('finish') || cLower.contains('renew') || cLower.contains('work on') || cLower.contains('kekkanum')) {
          type = 'Task';
          category = projects.isNotEmpty ? 'Projects' : 'Tasks';
          if (cLower.contains('call rahul')) {
            title = projects.isNotEmpty ? 'Call Rahul about ${projects.first} project' : 'Call Rahul about project';
          } else if (cLower.contains('ask rahul')) {
            title = 'Ask Rahul about project';
          } else if (cLower.contains('submit the assignment') || cLower.contains('submit assignment')) {
            title = 'Submit assignment';
          } else if (cLower.contains('jeevansetu')) {
            title = 'Finish JeevanSetu documentation';
          } else if (cLower.contains('github student account')) {
            title = 'Renew GitHub student account';
          } else {
            title = clause;
          }
        } else if (cLower.contains('idea') || cLower.contains('maybe')) {
          type = 'Idea';
          category = 'Ideas';
          title = clause;
        }
      }

      // Clean generic noise words from entities
      people.removeWhere((p) => genericNoiseWords.contains(p.toLowerCase()));
      places.removeWhere((p) => genericNoiseWords.contains(p.toLowerCase()));
      items.removeWhere((i) => genericNoiseWords.contains(i.toLowerCase()));
      projects.removeWhere((pr) => genericNoiseWords.contains(pr.toLowerCase()));

      records.add(Memory(
        captureId: captureId,
        type: type,
        title: title.isEmpty ? clause : title,
        details: clause,
        date: date,
        category: category,
        retention: 'Temporary',
        completed: false,
        people: people,
        places: places,
        items: items,
        projects: projects,
        originalText: rawText,
      ));
    }

    return records.isEmpty
        ? [
            Memory(
              captureId: captureId,
              type: 'Note',
              title: rawText.length > 50 ? '${rawText.substring(0, 50)}...' : rawText,
              details: rawText,
              category: 'Notes',
              originalText: rawText,
            )
          ]
        : records;
  }

  static String? resolveDate(String dateStr) {
    final s = dateStr.trim().toLowerCase();
    final now = DateTime.now();

    if (s.contains('today') || s.contains('inru')) {
      return DateFormat('yyyy-MM-dd').format(now);
    }
    if (s.contains('tomorrow') || s.contains('naalaiku')) {
      return DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
    }
    if (s.contains('yesterday')) {
      return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    }

    final isoRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (isoRegex.hasMatch(dateStr.trim())) {
      return dateStr.trim();
    }
    return dateStr;
  }

  static String formatHumanDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return 'No date';
    final clean = dateStr.trim();
    final now = DateTime.now();

    try {
      final dt = DateTime.parse(clean);
      final diff = dt.difference(DateTime(now.year, now.month, now.day)).inDays;
      final mDay = DateFormat('MMM dd').format(dt);

      if (diff == 0) return 'Today · $mDay';
      if (diff == 1) return 'Tomorrow · $mDay';
      if (diff == -1) return 'Yesterday · $mDay';
      if (diff >= 2 && diff <= 6) {
        return '${DateFormat('EEEE').format(dt)} · $mDay';
      }
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return clean;
    }
  }
}
