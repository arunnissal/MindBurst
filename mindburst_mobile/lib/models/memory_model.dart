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
