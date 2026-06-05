import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../blocs/users/users_cubit.dart';
import '../../blocs/session/session_cubit.dart';
import '../../blocs/session/session_state.dart';
import '../../blocs/admin/admin_cubit.dart';
import '../../blocs/translation/translation_cubit.dart';
import '../../repositories/admin_repository.dart';
import 'dashboard/dashboard_screen.dart';
import 'users/users_screen.dart';
import 'settings/settings_screen.dart';
import 'translations/translations_tab.dart';
import 'documents/documents_tab.dart';
import 'ai/ai_screen.dart';
import 'database/database_screen.dart';
import 'logs/logs_screen.dart';
import 'notifications/notifications_screen.dart';
import 'security/security_screen.dart';
import 'invitations/invitations_screen.dart';  // [M2] Admin Meghívók
import 'backup/backup_screen.dart';
import 'config/config_screen.dart';            // [M5] App Konfig & Feature Flags
import 'sessions/sessions_screen.dart';         // [M6] Munkamenetek
import 'bug_reports/bug_reports_screen.dart';   // [M7] Bug Riportok
import 'deep_links/deep_links_screen.dart';     // Deep Link konfig

// ============================================================
// Admin HomeScreen – Drawer navigation
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    context.read<TranslationCubit>().loadTranslations('hu');
    context.read<AdminCubit>().initAdmin();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    });
  }

  static const _tabs = [
    _TabItem(icon: LucideIcons.layoutDashboard,  label: 'Dashboard'),
    _TabItem(icon: LucideIcons.users,             label: 'Felhasználók'),
    _TabItem(icon: LucideIcons.shieldAlert,       label: 'Biztonság'),         // [M1]
    _TabItem(icon: LucideIcons.userPlus,          label: 'Meghívók'),          // [M2]
    _TabItem(icon: LucideIcons.sliders,           label: 'App Konfig'),        // [M5]
    _TabItem(icon: LucideIcons.monitorSmartphone, label: 'Munkamenetek'),      // [M6]
    _TabItem(icon: Icons.bug_report_rounded,      label: 'Bug Riportok'),     // [M7]
    _TabItem(icon: LucideIcons.hardDrive,         label: 'Backup & Monitor'), // [M4]
    _TabItem(icon: LucideIcons.languages,         label: 'Fordítások'),
    _TabItem(icon: LucideIcons.fileText,          label: 'Dokumentumok'),
    _TabItem(icon: LucideIcons.cpu,               label: 'AI'),
    _TabItem(icon: LucideIcons.database,          label: 'Adatbázis'),
    _TabItem(icon: LucideIcons.activity,          label: 'Rendszernaplók'),
    _TabItem(icon: LucideIcons.bell,              label: 'Értesítések'),
    _TabItem(icon: LucideIcons.link,              label: 'Deep Links'),
    _TabItem(icon: LucideIcons.settings,          label: 'Beállítások'),
  ];

  static const int _settingsIndex = 15;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UsersCubit(
        repository: context.read<AdminRepository>(),
      )..load(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(LucideIcons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            _tabs[_currentIndex].label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        drawer: _buildDrawer(context),
        // IndexedStack megtartja az állapotot tab-váltáskor
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            DashboardScreen(),
            UsersScreen(),
            SecurityScreen(),         // [M1]
            InvitationsScreen(),      // [M2]
            ConfigScreen(),           // [M5]
            SessionsScreen(),         // [M6]
            BugReportsScreen(),       // [M7]
            BackupScreen(),           // [M4]
            TranslationsTab(),
            DocumentsTab(),
            AiScreen(),
            DatabaseScreen(),
            LogsScreen(),
            NotificationsScreen(),
            DeepLinksScreen(),
            SettingsScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────
            BlocBuilder<SessionCubit, SessionState>(
              builder: (context, session) {
                final email = session is SessionLoggedIn
                    ? session.profile.email
                    : '';
                return DrawerHeader(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.shield, color: AppColors.primary, size: 36),
                      const SizedBox(height: 8),
                      const Text(
                        'ADMIN PANEL',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 15),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          email,
                          style: TextStyle(
                              color: AppColors.onSurface.withValues(alpha: 0.55),
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (_appVersion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'v$_appVersion',
                          style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.6),
                              fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // ── Nav itemek ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < _tabs.length; i++)
                      if (i != _settingsIndex) _drawerItem(context, i),
                  ],
                ),
              ),
            ),

            // ── Alul: Beállítások + Kijelentkezés ──────────────────
            const Divider(color: Colors.white10, height: 1),
            _drawerItem(context, _settingsIndex),
            _drawerLogout(context),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, int i) {
    final tab    = _tabs[i];
    final active = i == _currentIndex;
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = i);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(tab.icon,
                color: active ? AppColors.primary : Colors.white54, size: 20),
            const SizedBox(width: 12),
            Text(
              tab.label,
              style: TextStyle(
                color:      active ? Colors.white : Colors.white54,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                fontSize:   14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerLogout(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.read<SessionCubit>().signOut();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(LucideIcons.logOut, color: AppColors.error, size: 20),
            const SizedBox(width: 12),
            Text(
              'Kijelentkezés',
              style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
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
