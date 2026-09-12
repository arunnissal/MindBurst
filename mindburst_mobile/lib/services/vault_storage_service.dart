import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/db_helper.dart';
import '../models/memory_model.dart';

class VaultStats {
  final String filePath;
  final int fileSizeBytes;
  final int totalMemories;
  final DateTime? lastModified;
  final bool fileExists;

  VaultStats({
    required this.filePath,
    required this.fileSizeBytes,
    required this.totalMemories,
    required this.lastModified,
    required this.fileExists,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// 100% Offline, Local-Only File Vault for MindBurst.
/// Automatically mirrors SQLite records to a human-readable, portable JSON file
/// on the device storage without any cloud or internet connection.
class VaultStorageService {
  static final VaultStorageService instance = VaultStorageService._init();
  static const String defaultVaultFileName = 'mindburst_vault.json';

  VaultStorageService._init();

  /// Gets the absolute File handle for the local file vault.
  Future<File> get _vaultFile async {
    final docsDir = await getApplicationDocumentsDirectory();
    final fullPath = p.join(docsDir.path, defaultVaultFileName);
    return File(fullPath);
  }

  /// Automatically syncs all SQLite memories into the local JSON file.
  /// Runs asynchronously and safely catches any file I/O exceptions.
  Future<void> autoSyncToLocalVault() async {
    try {
      final file = await _vaultFile;
      final memories = await DatabaseHelper.instance.getAllMemories();
      
      final vaultData = {
        'version': 2,
        'app': 'MindBurst',
        'export_timestamp': DateTime.now().toUtc().toIso8601String(),
        'storage_type': '100% Offline Local File Vault',
        'total_count': memories.length,
        'memories': memories.map((m) => m.toMap()).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(vaultData);
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      // Non-fatal, local auto-sync failure should not block UI
      print('[VaultStorageService] Auto-sync error: $e');
    }
  }

  /// Manually exports the vault to a specified file or timestamped backup file.
  Future<File> exportVaultToFile({String? customFileName}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    
    final fileName = customFileName ?? 'mindburst_backup_$timestamp.json';
    final targetFile = File(p.join(docsDir.path, fileName));

    final memories = await DatabaseHelper.instance.getAllMemories();
    final vaultData = {
      'version': 2,
      'app': 'MindBurst',
      'export_timestamp': now.toUtc().toIso8601String(),
      'storage_type': '100% Offline Local File Vault Backup',
      'total_count': memories.length,
      'memories': memories.map((m) => m.toMap()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(vaultData);
    await targetFile.writeAsString(jsonStr, flush: true);

    // Also update the primary live vault file
    await autoSyncToLocalVault();

    return targetFile;
  }

  /// Restores memories from a local JSON file back into the SQLite database.
  /// Returns the number of successfully imported memories.
  Future<int> importVaultFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Vault backup file does not exist at: $filePath');
    }

    final content = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(content);

    if (!data.containsKey('memories') || data['memories'] is! List) {
      throw Exception('Invalid MindBurst vault file format: missing memories list');
    }

    final List memoriesList = data['memories'] as List;
    int importedCount = 0;

    for (final item in memoriesList) {
      if (item is Map<String, dynamic>) {
        final mem = Memory.fromMap(item);
        // Ensure ID is null so SQLite assigns a fresh auto-increment ID
        final cleanMem = Memory(
          captureId: mem.captureId ?? 1,
          type: mem.type,
          title: mem.title,
          details: mem.details,
          date: mem.date,
          time: mem.time,
          category: mem.category,
          retention: mem.retention,
          completed: mem.completed,
          completedAt: mem.completedAt,
          people: mem.people,
          places: mem.places,
          items: mem.items,
          projects: mem.projects,
          originalText: mem.originalText,
        );

        await DatabaseHelper.instance.insertMemory(cleanMem);
        importedCount++;
      }
    }

    // Refresh primary vault after import
    await autoSyncToLocalVault();
    return importedCount;
  }

  /// Inspects the current state of the local file vault.
  Future<VaultStats> getVaultStats() async {
    try {
      final file = await _vaultFile;
      final exists = await file.exists();
      if (!exists) {
        return VaultStats(
          filePath: file.path,
          fileSizeBytes: 0,
          totalMemories: 0,
          lastModified: null,
          fileExists: false,
        );
      }

      final stat = await file.stat();
      int memoryCount = 0;
      try {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        if (data['memories'] is List) {
          memoryCount = (data['memories'] as List).length;
        }
      } catch (_) {}

      return VaultStats(
        filePath: file.path,
        fileSizeBytes: stat.size,
        totalMemories: memoryCount,
        lastModified: stat.modified,
        fileExists: true,
      );
    } catch (e) {
      return VaultStats(
        filePath: 'Unknown',
        fileSizeBytes: 0,
        totalMemories: 0,
        lastModified: null,
        fileExists: false,
      );
    }
  }
}
