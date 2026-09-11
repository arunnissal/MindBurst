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
      version: 1,
      onCreate: _createDB,
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
      SELECT m.*, c.original_text 
      FROM memories m
      JOIN captures c ON m.capture_id = c.id
      WHERE m.deleted_at IS NULL
      AND NOT (m.retention = 'Temporary' AND m.completed = 1)
    ''';
    List<dynamic> args = [];

    if (category != null && category != 'All') {
      sql += ' AND m.category = ?';
      args.add(category);
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
      SELECT m.*, c.original_text
      FROM memories m
      JOIN captures c ON m.capture_id = c.id
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
}
