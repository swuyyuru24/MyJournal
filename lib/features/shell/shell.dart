import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  static const _tabs = [
    (path: '/', label: 'Today', icon: Icons.today_outlined),
    (path: '/templates', label: 'Templates', icon: Icons.dashboard_outlined),
    (path: '/habits', label: 'Habits', icon: Icons.repeat_outlined),
    (path: '/goals', label: 'Goals', icon: Icons.flag_outlined),
    (path: '/settings', label: 'Settings', icon: Icons.settings_outlined),
  ];

  int get _selectedIndex {
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].path ||
          (i > 0 && location.startsWith('${_tabs[i].path}/'))) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
