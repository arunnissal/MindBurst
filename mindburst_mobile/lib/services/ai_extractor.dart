import 'package:intl/intl.dart';
import '../models/memory_model.dart';

class AIExtractor {
  static const Set<String> genericNoiseWords = {
    'project', 'the project', 'a project', 'that project', 'our project',
    'assignment', 'the assignment', 'a assignment', 'that assignment',
    'task', 'the task', 'a task', 'that task',
    'thing', 'the thing', 'things', 'item', 'items', 'someone', 'person', 'place',
    'need', 'need to', 'want to', 'have to', 'going', 'go'
  };

  static List<Memory> extractMemories(String rawText, int captureId) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return [
        Memory(
          captureId: captureId,
          type: 'Note',
          title: 'Empty Thought',
          details: rawText,
          category: 'Notes',
          originalText: rawText,
        )
      ];
    }

    final clauses = _splitIntoClauses(text);
    List<Memory> records = [];

    for (final clause in clauses) {
      final mem = _processClause(clause, rawText, captureId);
      records.add(mem);
    }

    return records.isEmpty
        ? [
            Memory(
              captureId: captureId,
              type: 'Note',
              title: text.length > 50 ? '${text.substring(0, 50)}...' : text,
              details: text,
              category: 'Notes',
              originalText: rawText,
            )
          ]
        : records;
  }

  static List<String> _splitIntoClauses(String text) {
    // Pre-normalize times written with dots (e.g. "7.40pm", "7.30 am", "7.40 pm") to colons
    var normalized = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2})\.(\d{2})\s*(am|pm|AM|PM)?\b'),
      (m) => '${m.group(1)}:${m.group(2)}${m.group(3) != null ? " ${m.group(3)}" : ""}',
    );

    // Protect decimal quantities like 1.5, 2.5
    normalized = normalized.replaceAllMapped(
      RegExp(r'(\d+)\.(\d+)'),
      (m) => '${m.group(1)}__DOT__${m.group(2)}',
    );

    final clauseRegex = RegExp(
      r'(?:[\.\;\!\?\n]+|\,\s*and\s+|\band\s+also\b|\band\s+then\b|\bapram\b|\bapparam\b|\band\s+(?=(?:remind|call|buy|take|carry|pack|submit|check|finish|renew|pay|meet|send|clean|wash|study|go\b|need\b|we\b|i\b)))',
      caseSensitive: false,
    );

    final parts = normalized
        .split(clauseRegex)
        .map((p) => p.replaceAll('__DOT__', '.').trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return parts.isEmpty ? [text] : parts;
  }

  static Memory _processClause(String clause, String originalText, int captureId) {
    final cLower = clause.toLowerCase();

    List<String> people = [];
    List<String> places = [];
    List<String> items = [];
    List<String> projects = [];
    String? date;
    String? time;

    // --- 1. Detect Dates ---
    if (cLower.contains('tomorrow') || cLower.contains('naalaiku') || cLower.contains('nalaiku')) {
      date = resolveDate('Tomorrow');
    } else if (cLower.contains('today') || cLower.contains('inru') || cLower.contains('inniku') || cLower.contains('tonight')) {
      date = resolveDate('Today');
    } else if (cLower.contains('yesterday') || cLower.contains('naethu') || cLower.contains('nethu')) {
      date = resolveDate('Yesterday');
    } else {
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      for (final d in days) {
        if (cLower.contains(d)) {
          date = resolveDate(d);
          break;
        }
      }
    }

    // --- 2. Detect Time ---
    final timeMatch = RegExp(
      r'\b(?:at\s+)?(\d{1,2}(?::\d{2})?\s*(?:am|pm))\b|\bat\s+(\d{1,2}(?::\d{2})?)\b|\b([01]?\d|2[0-3]):([0-5]\d)\b',
      caseSensitive: false,
    ).firstMatch(clause);
    if (timeMatch != null) {
      final rawTime = timeMatch.group(0)?.trim() ?? '';
      time = _normalizeTimeDisplay(rawTime);
    }

    // --- 3. Detect People (Dynamic, NO hardcoded names) ---
    // Common relational / professional roles
    final genericRoles = ['mom', 'dad', 'brother', 'sister', 'boss', 'manager', 'sir', 'doctor', 'professor', 'friend', 'colleague', 'team', 'client'];
    for (final role in genericRoles) {
      if (RegExp('\\b$role\\b', caseSensitive: false).hasMatch(clause)) {
        people.add(_capitalize(role));
      }
    }

    // Dynamic pattern: [call / meet / ask / tell / with] [Name] (e.g. "call John", "meet Dr. Smith")
    final actionNameMatch = RegExp(r'\b(?:call|meet|ask|tell|with|pay|return to)\s+([A-Z][a-z]+)\b').firstMatch(clause);
    if (actionNameMatch != null) {
      final pName = actionNameMatch.group(1)!;
      if (!people.contains(pName) && !genericNoiseWords.contains(pName.toLowerCase()) && !_isDayOfWeek(pName)) {
        people.add(pName);
      }
    }

    // Tanglish pattern: [Name] ku, [Name] kitta, [Name] oda
    final tanglishPersonMatch = RegExp(r'\b([A-Z][a-z]+)\s*(?:ku|kitta|oda)\b').firstMatch(clause);
    if (tanglishPersonMatch != null) {
      final pName = tanglishPersonMatch.group(1)!;
      if (!people.contains(pName) && !genericNoiseWords.contains(pName.toLowerCase()) && !_isDayOfWeek(pName)) {
        people.add(pName);
      }
    }

    // --- 4. Detect Places (Comprehensive) ---
    final knownPlaces = [
      'college', 'school', 'university', 'campus', 'institute',
      'office', 'work', 'workplace', 'home', 'gym', 'library',
      'hospital', 'clinic', 'pharmacy', 'medical', 'bank', 'atm',
      'supermarket', 'market', 'bazaar', 'grocery', 'shop', 'store', 'mall',
      'airport', 'station', 'railway station', 'bus stand', 'bus stop', 'metro',
      'temple', 'church', 'mosque', 'hotel', 'restaurant', 'cafe',
      'hostel', 'room', 'flat', 'apartment', 'salon'
    ];

    for (final pl in knownPlaces) {
      if (RegExp('\\b$pl\\b', caseSensitive: false).hasMatch(clause)) {
        places.add(_capitalize(pl));
      }
    }

    // Dynamic patterns: "go to [Place]", "go [Place]", "reach [Place]", "visit [Place]"
    final goToPlaceMatch = RegExp(r'\b(?:go to|go|reach|visit|heading to|travel to)\s+([a-zA-Z]+)\b', caseSensitive: false).firstMatch(clause);
    if (goToPlaceMatch != null) {
      final detected = goToPlaceMatch.group(1)!.trim();
      final cap = _capitalize(detected);
      if (!places.contains(cap) && !genericNoiseWords.contains(detected.toLowerCase()) && !_isDayOfWeek(detected) && !_isNoisePlace(detected)) {
        places.add(cap);
      }
    }

    // Tanglish place pattern: "[Place] ku ponum", "[Place] ku poga", "[Place] la"
    final tanglishPlaceMatch = RegExp(r'\b([a-zA-Z]+)\s*(?:ku\s*(?:ponum|poga|poren)|la\b)\b', caseSensitive: false).firstMatch(clause);
    if (tanglishPlaceMatch != null) {
      final plName = _capitalize(tanglishPlaceMatch.group(1)!);
      if (!places.contains(plName) && !genericNoiseWords.contains(plName.toLowerCase()) && !_isDayOfWeek(plName)) {
        places.add(plName);
      }
    }

    // --- 5. Detect Items ---
    final itemKeywords = [
      'charger', 'laptop', 'headphone', 'headphones', 'earphone', 'earphones',
      'power bank', 'id', 'id card', 'resume', 'cv', 'hall ticket', 'admit card',
      'keys', 'key', 'wallet', 'purse', 'bottle', 'water bottle', 'umbrella',
      'bag', 'backpack', 'pen', 'pencil', 'notebook', 'book', 'books',
      'passport', 'license', 'helmet', 'jacket', 'glasses', 'spectacles',
      'medicine', 'medicines', 'tablet', 'tablets',
      'dress', 'clothes', 'uniform', 'shoes',
      'milk', 'bread', 'eggs', 'curd', 'coffee', 'tea', 'vegetables', 'fruits'
    ];
    for (final it in itemKeywords) {
      if (RegExp('\\b$it\\b', caseSensitive: false).hasMatch(clause)) {
        final cleanItem = _normalizeItemName(it);
        if (!items.contains(cleanItem)) {
          items.add(cleanItem);
        }
      }
    }

    // --- 6. Detect Projects ---
    final knownProjects = ['mindburst', 'jeevansetu'];
    for (final pr in knownProjects) {
      if (cLower.contains(pr)) {
        projects.add(pr == 'mindburst' ? 'MindBurst' : 'JeevanSetu');
      }
    }
    if (cLower.contains('project') && projects.isEmpty) {
      projects.add('Project');
    }

    // --- 7. Determine Category, Type & Title ---
    String type = 'Note';
    String category = 'Notes';
    String title = clause;
    String retention = 'Temporary';

    // A. Carry Intent
    final isCarryVerb = cLower.contains('carry') ||
        cLower.contains('take') ||
        cLower.contains('bring') ||
        cLower.contains('pack') ||
        cLower.contains('grab') ||
        cLower.contains('pick up') ||
        cLower.contains('kondu po') ||
        cLower.contains('kondu ponum') ||
        cLower.contains('kondu va') ||
        cLower.contains('kondu varanum') ||
        cLower.contains('eduthutu po') ||
        cLower.contains('eduthutu va') ||
        cLower.contains('eduthuko') ||
        cLower.contains('edukanum') ||
        cLower.contains('vachiko');

    final hasCarryItem = items.any((i) => [
      'Resume', 'CV', 'Charger', 'Laptop', 'Headphones', 'Power bank',
      'ID Card', 'Keys', 'Wallet', 'Water bottle', 'Umbrella', 'Hall ticket',
      'Passport', 'License', 'Helmet'
    ].contains(i));

    if (isCarryVerb || (hasCarryItem && (places.isNotEmpty || cLower.contains('ku') || cLower.contains('to')))) {
      type = 'Carry';
      category = 'Carry';
      final placeStr = places.isNotEmpty ? ' to ${places.first}' : '';
      if (items.isNotEmpty) {
        title = 'Take ${items.join(" and ")}$placeStr';
      } else {
        title = 'Carry items$placeStr';
      }
    }
    // B. Shopping Intent
    else if (cLower.contains('buy') ||
        cLower.contains('purchase') ||
        cLower.contains('shopping') ||
        cLower.contains('order') ||
        cLower.contains('vaanganum') ||
        cLower.contains('vaanga') ||
        cLower.contains('grocery') ||
        cLower.contains('groceries') ||
        cLower.contains('supermarket')) {
      type = 'Shopping';
      category = 'Shopping';
      final shopItems = items.isNotEmpty ? items.join(", ") : '';
      title = shopItems.isNotEmpty ? 'Buy $shopItems' : _cleanActionTitle(clause, 'Buy');
    }
    // C. Action / Task / Reminder Intent
    else if (cLower.contains('need to go') ||
        cLower.contains('have to go') ||
        cLower.contains('must go') ||
        cLower.contains('go to') ||
        cLower.contains('ponum') ||
        cLower.contains('poga') ||
        cLower.contains('wash') ||
        cLower.contains('clean') ||
        cLower.contains('pananum') ||
        cLower.contains('pannanum') ||
        cLower.contains('seiyanum') ||
        cLower.contains('kudukanum') ||
        cLower.contains('tharanum') ||
        cLower.contains('return') ||
        cLower.contains('call') ||
        cLower.contains('phone') ||
        cLower.contains('pesanum') ||
        cLower.contains('kekkanum') ||
        cLower.contains('solla') ||
        cLower.contains('sollanum') ||
        cLower.contains('ask') ||
        cLower.contains('submit') ||
        cLower.contains('finish') ||
        cLower.contains('complete') ||
        cLower.contains('mudikanum') ||
        cLower.contains('send') ||
        cLower.contains('anupanum') ||
        cLower.contains('check') ||
        cLower.contains('paakanum') ||
        cLower.contains('prepare') ||
        cLower.contains('write') ||
        cLower.contains('ezhudhanum') ||
        cLower.contains('study') ||
        cLower.contains('padikanum') ||
        cLower.contains('recharge') ||
        cLower.contains('pay') ||
        cLower.contains('renew') ||
        cLower.contains('remind') ||
        cLower.contains('todo') ||
        cLower.contains('need to') ||
        cLower.contains('have to')) {
      if (cLower.contains('remind') || cLower.contains('remember to') || cLower.contains('maranthuraadha') || cLower.contains('alert') || cLower.contains('alarm')) {
        type = 'Reminder';
        category = 'Reminders';
      } else if (projects.isNotEmpty) {
        type = 'Task';
        category = 'Projects';
      } else {
        type = 'Task';
        category = 'Tasks';
      }

      // Smart title formatting
      if (category == 'Reminders') {
        final remMatch = RegExp(
          r'\b(?:remind\s+(?:me\s+)?(?:to|about)?|remember\s+to|maranthuraadha)\s+(.+)',
          caseSensitive: false,
        ).firstMatch(clause);
        if (remMatch != null) {
          var action = remMatch.group(1)!.trim();
          action = action.replaceAll(RegExp(r'\b(?:at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?|\d{1,2}(?::\d{2})?\s*(?:am|pm))\b', caseSensitive: false), '').trim();
          action = action.replaceAll(RegExp(r'\b(?:today|tomorrow|tonight|inniku|naalaiku|morning|afternoon|evening|night)\b', caseSensitive: false), '').trim();
          action = action.replaceAll(RegExp(r'^(?:to\s+|about\s+|at\s+)', caseSensitive: false), '').trim();
          if (action.isNotEmpty) {
            title = _capitalizeFirstLetter(action);
          } else if (time != null) {
            title = 'Reminder at $time';
          } else {
            title = 'Reminder';
          }
        } else if (time != null) {
          title = 'Reminder at $time';
        } else {
          title = 'Reminder';
        }
      } else if (cLower.contains('go to') || cLower.contains('need to go') || cLower.contains('ponum')) {
        final placeStr = places.isNotEmpty ? places.first : '';
        title = placeStr.isNotEmpty ? 'Go to $placeStr' : 'Go out';
      } else if (cLower.contains('wash')) {
        final itemStr = items.isNotEmpty ? items.first.toLowerCase() : 'clothes';
        title = 'Wash $itemStr';
      } else if (cLower.contains('clean')) {
        final placeStr = places.isNotEmpty ? places.first.toLowerCase() : 'room';
        title = 'Clean $placeStr';
      } else if (cLower.contains('money return') || (cLower.contains('return') && cLower.contains('money'))) {
        final personStr = people.isNotEmpty ? ' to ${people.first}' : '';
        title = 'Return money$personStr';
      } else if (cLower.contains('call') || cLower.contains('phone') || cLower.contains('pesanum')) {
        final personStr = people.isNotEmpty ? people.first : '';
        title = personStr.isNotEmpty ? 'Call $personStr' : 'Make phone call';
      } else if (cLower.contains('ask') || cLower.contains('kekkanum')) {
        final personStr = people.isNotEmpty ? ' ${people.first}' : '';
        title = 'Ask$personStr about ${projects.isNotEmpty ? projects.first : "task"}';
      } else if (cLower.contains('submit')) {
        title = projects.isNotEmpty ? 'Submit ${projects.first}' : 'Submit assignment';
      } else if (cLower.contains('renew')) {
        title = 'Renew subscription';
      } else if (cLower.contains('pay') || cLower.contains('recharge')) {
        if (cLower.contains('rent')) {
          title = cLower.contains('hostel') ? 'Pay hostel rent' : 'Pay rent';
        } else if (cLower.contains('mess')) {
          title = 'Pay mess fee';
        } else if (cLower.contains('recharge')) {
          title = 'Mobile recharge';
        } else if (cLower.contains('wifi') || cLower.contains('wi-fi')) {
          title = 'Pay WiFi bill';
        } else if (cLower.contains('gym')) {
          title = 'Pay gym fee';
        } else {
          title = 'Pay bill';
        }
      } else {
        title = _cleanActionSummary(clause);
      }
    }
    // D. Event Intent
    else if (cLower.contains('meeting') ||
        cLower.contains('interview') ||
        cLower.contains('class') ||
        cLower.contains('exam') ||
        cLower.contains('appointment') ||
        cLower.contains('doctor') ||
        cLower.contains('iruku')) {
      type = 'Event';
      category = 'Events';
      final placeStr = places.isNotEmpty ? ' at ${places.first}' : '';
      final timeStr = time != null ? ' ($time)' : '';
      if (cLower.contains('interview')) {
        title = 'Interview$placeStr$timeStr';
      } else if (cLower.contains('meeting')) {
        title = 'Meeting$placeStr$timeStr';
      } else if (cLower.contains('exam')) {
        title = 'Exam$placeStr$timeStr';
      } else if (cLower.contains('class')) {
        title = 'Class$placeStr$timeStr';
      } else {
        title = _capitalizeFirstLetter(clause);
      }
    }
    // E. Ideas
    else if (cLower.contains('idea') || cLower.contains('maybe') || cLower.contains('what if') || cLower.contains('startup')) {
      type = 'Idea';
      category = 'Ideas';
      retention = 'Permanent';
      title = _capitalizeFirstLetter(clause);
    }
    // F. Projects
    else if (projects.isNotEmpty) {
      type = 'Note';
      category = 'Projects';
      retention = 'Permanent';
      title = _capitalizeFirstLetter(clause);
    } else {
      type = 'Note';
      category = 'Notes';
      title = _capitalizeFirstLetter(clause);
    }

    // Clean generic noise words from entities
    people.removeWhere((p) => genericNoiseWords.contains(p.toLowerCase()));
    places.removeWhere((p) => genericNoiseWords.contains(p.toLowerCase()));
    items.removeWhere((i) => genericNoiseWords.contains(i.toLowerCase()));
    projects.removeWhere((pr) => genericNoiseWords.contains(pr.toLowerCase()));

    return Memory(
      captureId: captureId,
      type: type,
      title: title.isEmpty ? clause : title,
      details: clause,
      date: date,
      time: time,
      category: category,
      retention: retention,
      completed: false,
      people: people,
      places: places,
      items: items,
      projects: projects,
      originalText: originalText,
    );
  }

  static bool _isDayOfWeek(String s) {
    final lower = s.toLowerCase();
    return ['today', 'tomorrow', 'yesterday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'].contains(lower);
  }

  static bool _isNoisePlace(String s) {
    final lower = s.toLowerCase();
    return ['the', 'a', 'an', 'some', 'my', 'your', 'our', 'and', 'or', 'in', 'at', 'on', 'to'].contains(lower);
  }

  static String _cleanActionSummary(String clause) {
    var s = clause.trim();
    // Remove leading conversational prefixes
    s = s.replaceAll(RegExp(r'^(?:tomorrow|today|yesterday|namma|i\s+need\s+to|we\s+need\s+to|need\s+to|have\s+to|must|should|please)\s+', caseSensitive: false), '');
    return _capitalizeFirstLetter(s);
  }

  static String _normalizeItemName(String it) {
    final lower = it.toLowerCase();
    switch (lower) {
      case 'charger': return 'Charger';
      case 'laptop': return 'Laptop';
      case 'headphone':
      case 'headphones': return 'Headphones';
      case 'earphone':
      case 'earphones': return 'Earphones';
      case 'power bank': return 'Power bank';
      case 'id':
      case 'id card': return 'ID Card';
      case 'resume':
      case 'cv': return 'Resume';
      case 'hall ticket':
      case 'admit card': return 'Hall Ticket';
      case 'keys':
      case 'key': return 'Keys';
      case 'wallet':
      case 'purse': return 'Wallet';
      case 'bottle':
      case 'water bottle': return 'Water bottle';
      case 'umbrella': return 'Umbrella';
      case 'passport': return 'Passport';
      case 'license': return 'License';
      case 'helmet': return 'Helmet';
      case 'dress': return 'Dress';
      case 'clothes': return 'Clothes';
      case 'milk': return 'Milk';
      case 'bread': return 'Bread';
      case 'coffee': return 'Coffee';
      case 'tea': return 'Tea';
      case 'eggs': return 'Eggs';
      default: return _capitalize(it);
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  static String _capitalizeFirstLetter(String s) {
    if (s.trim().isEmpty) return s;
    final trimmed = s.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  static String _cleanActionTitle(String clause, String verb) {
    final words = clause.split(' ');
    if (words.length <= 5) return _capitalizeFirstLetter(clause);
    return '$verb ${words.take(4).join(" ")}';
  }

  static String _normalizeTimeDisplay(String raw) {
    var s = raw.replaceAll(RegExp(r'^at\s+', caseSensitive: false), '').trim();
    final m12 = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$', caseSensitive: false).firstMatch(s);
    if (m12 != null) {
      int hour = int.parse(m12.group(1)!);
      int minute = m12.group(2) != null ? int.parse(m12.group(2)!) : 0;
      final amPm = m12.group(3)?.toUpperCase();

      final minStr = minute.toString().padLeft(2, '0');
      if (amPm != null) {
        return '$hour:$minStr $amPm';
      } else {
        if (hour >= 12) {
          final h12 = hour == 12 ? 12 : hour - 12;
          return '$h12:$minStr PM';
        } else {
          return '$hour:$minStr AM';
        }
      }
    }
    return raw;
  }

  static String? resolveDate(String dateStr) {
    final s = dateStr.trim().toLowerCase();
    final now = DateTime.now();

    if (s.contains('today') || s.contains('inru') || s.contains('inniku')) {
      return DateFormat('yyyy-MM-dd').format(now);
    }
    if (s.contains('tomorrow') || s.contains('naalaiku') || s.contains('nalaiku')) {
      return DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
    }
    if (s.contains('yesterday') || s.contains('naethu') || s.contains('nethu')) {
      return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    }

    final days = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final entry in days.entries) {
      if (s.contains(entry.key)) {
        int diff = entry.value - now.weekday;
        if (diff <= 0) diff += 7;
        return DateFormat('yyyy-MM-dd').format(now.add(Duration(days: diff)));
      }
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
