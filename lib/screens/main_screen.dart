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

  // NOT const — StatefulWidget children need their own State lifecycle.
  // const/static would prevent late final fields in initState from working.
  final List<Widget> _pages = const [
    DashboardScreen(),
    ControlScreen(),
    LogScreen(),
    PlantConfigScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWideScreen = MediaQuery.of(context).size.width >= 600;

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
    );

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined, color: cs.onSurfaceVariant),
                  selectedIcon: Icon(Icons.dashboard, color: cs.primary),
                  label: const Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.tune_outlined, color: cs.onSurfaceVariant),
                  selectedIcon: Icon(Icons.tune, color: cs.primary),
                  label: const Text('Kontrol'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.article_outlined, color: cs.onSurfaceVariant),
                  selectedIcon: Icon(Icons.article, color: cs.primary),
                  label: const Text('Log'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.eco_outlined, color: cs.onSurfaceVariant),
                  selectedIcon: Icon(Icons.eco, color: cs.primary),
                  label: const Text('Tanaman'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
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
