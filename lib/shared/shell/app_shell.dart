import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon:          Icon(Icons.dashboard_outlined),
            selectedIcon:  Icon(Icons.dashboard),
            label:         'Dashboard',
          ),
          NavigationDestination(
            icon:          Icon(Icons.inventory_2_outlined),
            selectedIcon:  Icon(Icons.inventory_2),
            label:         'Inventory',
          ),
          NavigationDestination(
            icon:          Icon(Icons.swap_vert_outlined),
            selectedIcon:  Icon(Icons.swap_vert),
            label:         'Movements',
          ),
          NavigationDestination(
            icon:          Icon(Icons.fact_check_outlined),
            selectedIcon:  Icon(Icons.fact_check),
            label:         'Count',
          ),
          NavigationDestination(
            icon:          Icon(Icons.bar_chart_outlined),
            selectedIcon:  Icon(Icons.bar_chart),
            label:         'Reports',
          ),
        ],
      ),
    );
  }
}
