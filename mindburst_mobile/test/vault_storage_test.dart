import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindburst_app/models/memory_model.dart';
import 'package:mindburst_app/services/vault_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultStorageService Tests', () {
    test('VaultStats formats byte sizes properly', () {
      final stats1 = VaultStats(
        filePath: '/test/vault.json',
        fileSizeBytes: 512,
        totalMemories: 5,
        lastModified: DateTime.now(),
        fileExists: true,
      );
      expect(stats1.formattedSize, '512 B');

      final stats2 = VaultStats(
        filePath: '/test/vault.json',
        fileSizeBytes: 20480,
        totalMemories: 50,
        lastModified: DateTime.now(),
        fileExists: true,
      );
      expect(stats2.formattedSize, '20.0 KB');
    });

    test('Can serialize and parse vault backup data format', () {
      final mem = Memory(
        id: 1,
        captureId: 10,
        type: 'Task',
        title: 'Complete compiler lab',
        details: 'Lab record submission',
        category: 'Tasks',
        originalText: 'Complete compiler lab',
        date: '2026-09-15',
        time: '10:00 AM',
        people: ['Professor'],
        places: ['Lab'],
        items: ['Lab Record'],
      );

      final vaultData = {
        'version': 2,
        'app': 'MindBurst',
        'export_timestamp': DateTime.now().toUtc().toIso8601String(),
        'storage_type': '100% Offline Local File Vault',
        'total_count': 1,
        'memories': [mem.toMap()],
      };

      final jsonString = jsonEncode(vaultData);
      final decoded = jsonDecode(jsonString);

      expect(decoded['version'], 2);
      expect(decoded['app'], 'MindBurst');
      expect(decoded['total_count'], 1);

      final restoredList = decoded['memories'] as List;
      expect(restoredList.length, 1);

      final restoredMem = Memory.fromMap(restoredList[0]);
      expect(restoredMem.title, 'Complete compiler lab');
      expect(restoredMem.category, 'Tasks');
    });
  });
}
