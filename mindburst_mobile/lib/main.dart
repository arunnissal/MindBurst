import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
