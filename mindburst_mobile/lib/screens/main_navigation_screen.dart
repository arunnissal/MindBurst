import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'burst_screen.dart';
import 'all_screen.dart';
import 'ask_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<AllScreenState> _allScreenKey = GlobalKey<AllScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      BurstScreen(
        onSaved: () {
          setState(() {
            _currentIndex = 1;
          });
          _allScreenKey.currentState?.refreshMemories();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Memories extracted and saved successfully!'),
              backgroundColor: AppTheme.goldAccent,
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
      AllScreen(key: _allScreenKey),
      const AskScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          border: Border(
            top: BorderSide(color: AppTheme.goldBorder, width: 0.8),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: AppTheme.cardBg,
          selectedItemColor: AppTheme.goldAccent,
          unselectedItemColor: AppTheme.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == 1) {
              _allScreenKey.currentState?.refreshMemories();
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.bolt_outlined),
              activeIcon: Icon(Icons.bolt),
              label: 'Burst',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.layers_outlined),
              activeIcon: Icon(Icons.layers),
              label: 'Memories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined),
              activeIcon: Icon(Icons.psychology),
              label: 'Ask Mind',
            ),
          ],
        ),
      ),
    );
  }
}
