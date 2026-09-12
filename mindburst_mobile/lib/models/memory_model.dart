class Capture {
  final int? id;
  final String originalText;
  final String inputSource;
  final String? createdAt;

  Capture({
    this.id,
    required this.originalText,
    this.inputSource = 'text',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_text': originalText,
      'input_source': inputSource,
      'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory Capture.fromMap(Map<String, dynamic> map) {
    return Capture(
      id: map['id'],
      originalText: map['original_text'] ?? '',
      inputSource: map['input_source'] ?? 'text',
      createdAt: map['created_at'],
    );
  }
}

class Memory {
  int? id;
  int? captureId;
  String type; // 'Task', 'Carry', 'Shopping', 'Idea', 'Memory', 'Note'
  String title;
  String details;
  String? date; // 'YYYY-MM-DD' or relative
  String? time;
  String category;
  String retention; // 'Temporary', 'Keep Until Delete', 'Permanent'
  bool completed;
  String? completedAt;
  String? createdAt;
  String? updatedAt;
  String? deletedAt;

  List<String> people;
  List<String> places;
  List<String> items;
  List<String> projects;
  String? originalText;

  Memory({
    this.id,
    this.captureId,
    this.type = 'Note',
    required this.title,
    this.details = '',
    this.date,
    this.time,
    this.category = 'Notes',
    this.retention = 'Temporary',
    this.completed = false,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    List<String>? people,
    List<String>? places,
    List<String>? items,
    List<String>? projects,
    this.originalText,
  })  : people = people ?? [],
        places = places ?? [],
        items = items ?? [],
        projects = projects ?? [];

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': id,
      'capture_id': captureId,
      'type': type,
      'title': title,
      'details': details,
      'date': date,
      'time': time,
      'category': category,
      'retention': retention,
      'completed': completed ? 1 : 0,
      'completed_at': completedAt,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
      'deleted_at': deletedAt,
    };
  }

  factory Memory.fromMap(Map<String, dynamic> map) {
    return Memory(
      id: map['id'],
      captureId: map['capture_id'],
      type: map['type'] ?? 'Note',
      title: map['title'] ?? '',
      details: map['details'] ?? '',
      date: map['date'],
      time: map['time'],
      category: map['category'] ?? 'Notes',
      retention: map['retention'] ?? 'Temporary',
      completed: (map['completed'] ?? 0) == 1,
      completedAt: map['completed_at'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      deletedAt: map['deleted_at'],
      originalText: map['original_text'],
    );
  }

  Memory copyWith({
    int? id,
    int? captureId,
    String? type,
    String? title,
    String? details,
    String? date,
    String? time,
    String? category,
    String? retention,
    bool? completed,
    String? completedAt,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    List<String>? people,
    List<String>? places,
    List<String>? items,
    List<String>? projects,
    String? originalText,
  }) {
    return Memory(
      id: id ?? this.id,
      captureId: captureId ?? this.captureId,
      type: type ?? this.type,
      title: title ?? this.title,
      details: details ?? this.details,
      date: date ?? this.date,
      time: time ?? this.time,
      category: category ?? this.category,
      retention: retention ?? this.retention,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      people: people ?? List.from(this.people),
      places: places ?? List.from(this.places),
      items: items ?? List.from(this.items),
      projects: projects ?? List.from(this.projects),
      originalText: originalText ?? this.originalText,
    );
  }
}

class UserProfile {
  final int? id;
  final String livingSituation; // 'hostel', 'rented', 'home'
  final String profession; // 'student', 'professional', 'homemaker', 'business'
  final String? userName;
  final String? collegeName;
  final int rentDueDay; // 1 to 31 (default 5)
  final int messDueDay; // 1 to 31 (default 5)
  final bool hasMessFee;

  UserProfile({
    this.id,
    this.livingSituation = 'hostel',
    this.profession = 'student',
    this.userName,
    this.collegeName,
    this.rentDueDay = 5,
    this.messDueDay = 5,
    this.hasMessFee = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'living_situation': livingSituation,
      'profession': profession,
      'user_name': userName,
      'college_name': collegeName,
      'rent_due_day': rentDueDay,
      'mess_due_day': messDueDay,
      'has_mess_fee': hasMessFee ? 1 : 0,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      livingSituation: map['living_situation'] ?? 'hostel',
      profession: map['profession'] ?? 'student',
      userName: map['user_name'],
      collegeName: map['college_name'],
      rentDueDay: map['rent_due_day'] ?? 5,
      messDueDay: map['mess_due_day'] ?? 5,
      hasMessFee: (map['has_mess_fee'] ?? 1) == 1,
    );
  }

  UserProfile copyWith({
    int? id,
    String? livingSituation,
    String? profession,
    String? userName,
    String? collegeName,
    int? rentDueDay,
    int? messDueDay,
    bool? hasMessFee,
  }) {
    return UserProfile(
      id: id ?? this.id,
      livingSituation: livingSituation ?? this.livingSituation,
      profession: profession ?? this.profession,
      userName: userName ?? this.userName,
      collegeName: collegeName ?? this.collegeName,
      rentDueDay: rentDueDay ?? this.rentDueDay,
      messDueDay: messDueDay ?? this.messDueDay,
      hasMessFee: hasMessFee ?? this.hasMessFee,
    );
  }
}

class RecurringBill {
  final int? id;
  final String title;
  final int dueDay; // 1 to 31
  final double? amount;
  final String category; // 'Hostel', 'Personal', etc.

  RecurringBill({
    this.id,
    required this.title,
    required this.dueDay,
    this.amount,
    this.category = 'Personal',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'due_day': dueDay,
      'amount': amount,
      'category': category,
    };
  }

  factory RecurringBill.fromMap(Map<String, dynamic> map) {
    return RecurringBill(
      id: map['id'],
      title: map['title'] ?? '',
      dueDay: map['due_day'] ?? 1,
      amount: map['amount'] != null ? (map['amount'] as num).toDouble() : null,
      category: map['category'] ?? 'Personal',
    );
  }
}

class DailyRoutine {
  final int? id;
  final String title;
  final String timeSlot; // 'Morning', 'Afternoon', 'Evening', 'Night'
  final String contextTag; // 'all', 'hostel', 'home'
  final bool isCompleted;
  final String? lastCompletedDate; // 'YYYY-MM-DD'
  final int streakCount;

  DailyRoutine({
    this.id,
    required this.title,
    this.timeSlot = 'Morning',
    this.contextTag = 'all',
    this.isCompleted = false,
    this.lastCompletedDate,
    this.streakCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'time_slot': timeSlot,
      'context_tag': contextTag,
      'is_completed': isCompleted ? 1 : 0,
      'last_completed_date': lastCompletedDate,
      'streak_count': streakCount,
    };
  }

  factory DailyRoutine.fromMap(Map<String, dynamic> map) {
    return DailyRoutine(
      id: map['id'],
      title: map['title'] ?? '',
      timeSlot: map['time_slot'] ?? 'Morning',
      contextTag: map['context_tag'] ?? 'all',
      isCompleted: (map['is_completed'] ?? 0) == 1,
      lastCompletedDate: map['last_completed_date'],
      streakCount: map['streak_count'] ?? 0,
    );
  }

  DailyRoutine copyWith({
    int? id,
    String? title,
    String? timeSlot,
    String? contextTag,
    bool? isCompleted,
    String? lastCompletedDate,
    int? streakCount,
  }) {
    return DailyRoutine(
      id: id ?? this.id,
      title: title ?? this.title,
      timeSlot: timeSlot ?? this.timeSlot,
      contextTag: contextTag ?? this.contextTag,
      isCompleted: isCompleted ?? this.isCompleted,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      streakCount: streakCount ?? this.streakCount,
    );
  }
}

