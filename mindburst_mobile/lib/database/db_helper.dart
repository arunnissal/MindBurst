import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/memory_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mindburst.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE captures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_text TEXT NOT NULL,
        input_source TEXT NOT NULL DEFAULT 'text',
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        capture_id INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'Note',
        title TEXT NOT NULL,
        details TEXT DEFAULT '',
        date TEXT,
        time TEXT,
        category TEXT NOT NULL DEFAULT 'Notes',
        retention TEXT NOT NULL DEFAULT 'Temporary',
        completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (capture_id) REFERENCES captures (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE entities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        memory_id INTEGER NOT NULL,
        entity_type TEXT NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (memory_id) REFERENCES memories (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('CREATE INDEX idx_mem_category ON memories(category);');
    await db.execute('CREATE INDEX idx_mem_retention ON memories(retention);');
    await db.execute('CREATE INDEX idx_mem_completed ON memories(completed);');
    await db.execute('CREATE INDEX idx_mem_deleted ON memories(deleted_at);');
    await db.execute('CREATE INDEX idx_ent_memory ON entities(memory_id);');
    await _createSecondBrainTables(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSecondBrainTables(db);
    }
  }

  Future<void> _createSecondBrainTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        living_situation TEXT NOT NULL DEFAULT 'hostel',
        user_name TEXT,
        college_name TEXT,
        rent_due_day INTEGER NOT NULL DEFAULT 5,
        mess_due_day INTEGER NOT NULL DEFAULT 5,
        has_mess_fee INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        due_day INTEGER NOT NULL DEFAULT 1,
        amount REAL,
        category TEXT NOT NULL DEFAULT 'Personal'
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        time_slot TEXT NOT NULL DEFAULT 'Morning',
        context_tag TEXT NOT NULL DEFAULT 'all',
        is_completed INTEGER NOT NULL DEFAULT 0,
        last_completed_date TEXT,
        streak_count INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // Seed default routines if empty
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM daily_routines')) ?? 0;
    if (count == 0) {
      await db.insert('daily_routines', {
        'title': 'Drink Water & Morning Stretch',
        'time_slot': 'Morning',
        'context_tag': 'all',
        'is_completed': 0,
        'streak_count': 0,
      });
      await db.insert('daily_routines', {
        'title': "Review Today's Plan in MindBurst",
        'time_slot': 'Morning',
        'context_tag': 'all',
        'is_completed': 0,
        'streak_count': 0,
      });
      await db.insert('daily_routines', {
        'title': 'College Lectures & Lab Prep',
        'time_slot': 'Afternoon',
        'context_tag': 'all',
        'is_completed': 0,
        'streak_count': 0,
      });
      await db.insert('daily_routines', {
        'title': 'Hostel Room Cleanup & Laundry Check',
        'time_slot': 'Evening',
        'context_tag': 'hostel',
        'is_completed': 0,
        'streak_count': 0,
      });
      await db.insert('daily_routines', {
        'title': 'Day Recap & Wind Down',
        'time_slot': 'Night',
        'context_tag': 'all',
        'is_completed': 0,
        'streak_count': 0,
      });
    }

    // Seed default profile if empty
    final profileCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM user_profile')) ?? 0;
    if (profileCount == 0) {
      await db.insert('user_profile', {
        'living_situation': 'hostel',
        'rent_due_day': 5,
        'mess_due_day': 5,
        'has_mess_fee': 1,
      });
    }
  }

  // --- Captures ---
  Future<Capture> createCapture(String text, {String source = 'text'}) async {
    final db = await database;
    final capture = Capture(originalText: text, inputSource: source);
    final id = await db.insert('captures', capture.toMap());
    return Capture(
      id: id,
      originalText: text,
      inputSource: source,
      createdAt: capture.createdAt,
    );
  }

  Future<void> deleteCapture(int id) async {
    final db = await database;
    await db.delete('captures', where: 'id = ?', whereArgs: [id]);
  }

  // --- Memories ---
  Future<void> saveMemories(List<Memory> memories) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final mem in memories) {
        final memId = await txn.insert('memories', mem.toMap());
        mem.id = memId;

        for (final p in mem.people) {
          if (p.trim().isNotEmpty) {
            await txn.insert('entities', {
              'memory_id': memId,
              'entity_type': 'person',
              'name': p.trim(),
            });
          }
        }
        for (final p in mem.places) {
          if (p.trim().isNotEmpty) {
            await txn.insert('entities', {
              'memory_id': memId,
              'entity_type': 'place',
              'name': p.trim(),
            });
          }
        }
        for (final i in mem.items) {
          if (i.trim().isNotEmpty) {
            await txn.insert('entities', {
              'memory_id': memId,
              'entity_type': 'item',
              'name': i.trim(),
            });
          }
        }
        for (final pr in mem.projects) {
          if (pr.trim().isNotEmpty) {
            await txn.insert('entities', {
              'memory_id': memId,
              'entity_type': 'project',
              'name': pr.trim(),
            });
          }
        }
      }
    });
  }

  Future<List<Memory>> getActiveMemories({
    String? query,
    String? category,
    String? retention,
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;

    String sql = '''
      SELECT m.*, COALESCE(c.original_text, '') AS original_text 
      FROM memories m
      LEFT JOIN captures c ON m.capture_id = c.id
      WHERE m.deleted_at IS NULL
      AND NOT (m.retention = 'Temporary' AND m.completed = 1)
    ''';
    List<dynamic> args = [];

    if (category != null && category != 'All') {
      if (category == 'Places') {
        sql += ''' AND (
          m.category = 'Places' OR 
          m.id IN (SELECT memory_id FROM entities WHERE entity_type = 'place')
        )''';
      } else if (category == 'Carry') {
        sql += ''' AND (
          m.category = 'Carry' OR 
          m.type = 'Carry' OR 
          m.id IN (SELECT memory_id FROM entities WHERE entity_type = 'item')
        )''';
      } else if (category == 'Projects') {
        sql += ''' AND (
          m.category = 'Projects' OR 
          m.id IN (SELECT memory_id FROM entities WHERE entity_type = 'project')
        )''';
      } else {
        sql += ' AND m.category = ?';
        args.add(category);
      }
    }

    if (retention != null && retention != 'All') {
      sql += ' AND m.retention = ?';
      args.add(retention);
    }

    if (startDate != null && endDate != null) {
      if (startDate == endDate) {
        sql += ' AND (m.date = ? OR (m.date IS NULL AND SUBSTR(m.created_at, 1, 10) = ?))';
        args.addAll([startDate, startDate]);
      } else {
        sql += ' AND ((m.date BETWEEN ? AND ?) OR (m.date IS NULL AND SUBSTR(m.created_at, 1, 10) BETWEEN ? AND ?))';
        args.addAll([startDate, endDate, startDate, endDate]);
      }
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      sql += '''
        AND (
          m.title LIKE ? OR
          m.details LIKE ? OR
          c.original_text LIKE ? OR
          m.category LIKE ? OR
          m.id IN (SELECT memory_id FROM entities WHERE name LIKE ?)
        )
      ''';
      args.addAll([q, q, q, q, q]);
    }

    sql += ' ORDER BY m.created_at DESC;';

    final rows = await db.rawQuery(sql, args);
    List<Memory> list = [];
    for (final row in rows) {
      final mem = Memory.fromMap(row);
      await _loadEntities(db, mem);
      list.add(mem);
    }
    return list;
  }

  Future<List<Memory>> getDeletedMemories() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT m.*, COALESCE(c.original_text, '') AS original_text
      FROM memories m
      LEFT JOIN captures c ON m.capture_id = c.id
      WHERE m.deleted_at IS NOT NULL
      ORDER BY m.deleted_at DESC;
    ''');
    List<Memory> list = [];
    for (final row in rows) {
      final mem = Memory.fromMap(row);
      await _loadEntities(db, mem);
      list.add(mem);
    }
    return list;
  }

  Future<void> updateMemory(Memory mem) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'memories',
        mem.toMap(),
        where: 'id = ?',
        whereArgs: [mem.id],
      );

      // Refresh entities
      await txn.delete('entities', where: 'memory_id = ?', whereArgs: [mem.id]);
      for (final p in mem.people) {
        if (p.trim().isNotEmpty) {
          await txn.insert('entities', {'memory_id': mem.id, 'entity_type': 'person', 'name': p.trim()});
        }
      }
      for (final p in mem.places) {
        if (p.trim().isNotEmpty) {
          await txn.insert('entities', {'memory_id': mem.id, 'entity_type': 'place', 'name': p.trim()});
        }
      }
      for (final i in mem.items) {
        if (i.trim().isNotEmpty) {
          await txn.insert('entities', {'memory_id': mem.id, 'entity_type': 'item', 'name': i.trim()});
        }
      }
      for (final pr in mem.projects) {
        if (pr.trim().isNotEmpty) {
          await txn.insert('entities', {'memory_id': mem.id, 'entity_type': 'project', 'name': pr.trim()});
        }
      }
    });
  }

  Future<void> toggleComplete(Memory mem) async {
    final db = await database;
    final newCompleted = !mem.completed;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'memories',
      {
        'completed': newCompleted ? 1 : 0,
        'completed_at': newCompleted ? now : null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [mem.id],
    );
    mem.completed = newCompleted;
    mem.completedAt = newCompleted ? now : null;
  }

  Future<void> softDelete(int id) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'memories',
      {'deleted_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreMemory(int id) async {
    final db = await database;
    await db.update(
      'memories',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteForever(int id) async {
    final db = await database;
    await db.delete('entities', where: 'memory_id = ?', whereArgs: [id]);
    await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _loadEntities(Database db, Memory memory) async {
    final rows = await db.query(
      'entities',
      where: 'memory_id = ?',
      whereArgs: [memory.id],
    );
    memory.people = rows.where((r) => r['entity_type'] == 'person').map((r) => r['name'] as String).toList();
    memory.places = rows.where((r) => r['entity_type'] == 'place').map((r) => r['name'] as String).toList();
    memory.items = rows.where((r) => r['entity_type'] == 'item').map((r) => r['name'] as String).toList();
    memory.projects = rows.where((r) => r['entity_type'] == 'project').map((r) => r['name'] as String).toList();
  }

  // --- User Profile ---
  Future<UserProfile> getUserProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', limit: 1);
    if (rows.isNotEmpty) {
      return UserProfile.fromMap(rows.first);
    }
    final defaultProfile = UserProfile();
    final id = await db.insert('user_profile', defaultProfile.toMap());
    return defaultProfile.copyWith(id: id);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    final rows = await db.query('user_profile', limit: 1);
    if (rows.isNotEmpty) {
      final existingId = rows.first['id'] as int;
      await db.update('user_profile', profile.toMap(), where: 'id = ?', whereArgs: [existingId]);
    } else {
      await db.insert('user_profile', profile.toMap());
    }
  }

  // --- Recurring Bills ---
  Future<List<RecurringBill>> getRecurringBills() async {
    final db = await database;
    final rows = await db.query('recurring_bills', orderBy: 'due_day ASC');
    return rows.map((r) => RecurringBill.fromMap(r)).toList();
  }

  Future<int> addRecurringBill(RecurringBill bill) async {
    final db = await database;
    return await db.insert('recurring_bills', bill.toMap());
  }

  Future<void> deleteRecurringBill(int id) async {
    final db = await database;
    await db.delete('recurring_bills', where: 'id = ?', whereArgs: [id]);
  }

  // --- Daily Routines ---
  Future<List<DailyRoutine>> getDailyRoutines({String? contextTag}) async {
    final db = await database;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    List<Map<String, dynamic>> rows;
    if (contextTag != null && contextTag != 'all') {
      rows = await db.query(
        'daily_routines',
        where: "context_tag = 'all' OR context_tag = ?",
        whereArgs: [contextTag],
        orderBy: 'id ASC',
      );
    } else {
      rows = await db.query('daily_routines', orderBy: 'id ASC');
    }

    final routines = <DailyRoutine>[];
    for (final r in rows) {
      final routine = DailyRoutine.fromMap(r);
      // Auto-reset if last completed was on an earlier date
      if (routine.isCompleted && routine.lastCompletedDate != null && routine.lastCompletedDate != todayStr) {
        await db.update(
          'daily_routines',
          {'is_completed': 0},
          where: 'id = ?',
          whereArgs: [routine.id],
        );
        routines.add(routine.copyWith(isCompleted: false));
      } else {
        routines.add(routine);
      }
    }
    return routines;
  }

  Future<void> toggleRoutineCompletion(DailyRoutine routine) async {
    final db = await database;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final willBeCompleted = !routine.isCompleted;

    int newStreak = routine.streakCount;
    if (willBeCompleted) {
      if (routine.lastCompletedDate != todayStr) {
        newStreak += 1;
      }
    } else {
      if (newStreak > 0) newStreak -= 1;
    }

    await db.update(
      'daily_routines',
      {
        'is_completed': willBeCompleted ? 1 : 0,
        'last_completed_date': willBeCompleted ? todayStr : routine.lastCompletedDate,
        'streak_count': newStreak,
      },
      where: 'id = ?',
      whereArgs: [routine.id],
    );
  }

  Future<int> addDailyRoutine(DailyRoutine routine) async {
    final db = await database;
    return await db.insert('daily_routines', routine.toMap());
  }

  Future<void> deleteDailyRoutine(int id) async {
    final db = await database;
    await db.delete('daily_routines', where: 'id = ?', whereArgs: [id]);
  }
}
