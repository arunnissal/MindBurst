import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation_screen.dart';

import 'database/db_helper.dart';
import 'services/vault_storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hook up 100% offline Local File Vault auto-mirroring
  DatabaseHelper.onDatabaseChanged = () {
    VaultStorageService.instance.autoSyncToLocalVault();
  };
  VaultStorageService.instance.autoSyncToLocalVault();

  runApp(const MindBurstApp());
}

class MindBurstApp extends StatelessWidget {
  const MindBurstApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindBurst',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScreen(),
    );
  }
}
