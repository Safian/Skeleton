import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'list/list_screen.dart';
import 'components_showcase/components_screen.dart';
import 'settings/settings_screen.dart';

// ============================================================
// HomeScreen – 4 tabos főkeret
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static final _tabs = [
    const _TabItem(icon: LucideIcons.layoutDashboard, label: 'Dashboard'),
    const _TabItem(icon: LucideIcons.list,             label: 'Lista'),
    const _TabItem(icon: LucideIcons.palette,          label: 'Komponensek'),
    const _TabItem(icon: LucideIcons.settings,         label: 'Beállítások'),
  ];

  static final _screens = [
    const DashboardScreen(),
    const ListScreen(),
    const ComponentsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.divider),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab      = _tabs[i];
                final selected = i == _currentIndex;
                final color    = selected
                    ? AppColors.primary
                    : AppColors.onSurface.withValues(alpha: 0.45);

                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tab.icon, size: 22, color: color),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: AppTypography.eyebrow.copyWith(
                            color: color,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width: selected ? 20 : 0,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}
