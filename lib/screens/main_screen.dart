import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'control_screen.dart';
import 'log_screen.dart';
import 'plant_config_screen.dart';

/// Root screen that hosts the [NavigationBar] and an [IndexedStack] to
/// preserve the state of each tab as the user navigates.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    DashboardScreen(),
    ControlScreen(),
    LogScreen(),
    PlantConfigScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: cs.onSurfaceVariant),
            selectedIcon: Icon(Icons.dashboard, color: cs.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined, color: cs.onSurfaceVariant),
            selectedIcon: Icon(Icons.tune, color: cs.primary),
            label: 'Kontrol',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined, color: cs.onSurfaceVariant),
            selectedIcon: Icon(Icons.article, color: cs.primary),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined, color: cs.onSurfaceVariant),
            selectedIcon: Icon(Icons.eco, color: cs.primary),
            label: 'Tanaman',
          ),
        ],
      ),
    );
  }
}
