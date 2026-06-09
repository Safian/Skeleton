import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../blocs/session/session_cubit.dart';
import '../../../blocs/session/session_state.dart';
import '../../../widgets/tutorial/tutorial_showcase.dart';

// ============================================================
// DashboardScreen – Tab 1
// [M4.2] ShowCaseWidget + TutorialAutoLaunch integráció
// ============================================================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWrapper(
      builder: (ctx) => _DashboardBody(showcaseCtx: ctx),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  final BuildContext showcaseCtx;
  const _DashboardBody({required this.showcaseCtx});

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final _keyWelcome = GlobalKey();
  final _keyStats   = GlobalKey();

  @override
  void initState() {
    super.initState();
    TutorialAutoLaunch.schedule(
      context: widget.showcaseCtx,
      screenId: 'dashboard',
      keys: [_keyWelcome, _keyStats],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state   = context.watch<SessionCubit>().state;
    final profile = state is SessionLoggedIn ? state.profile : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RadialBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => context.read<SessionCubit>().reloadProfile(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // AppBar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                    child: TutorialStep(
                      globalKey: _keyWelcome,
                      title: 'Üdvözöljük!',
                      description: 'Ez a főképernyő, innen érheted el az összes funkciót.',
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Üdvözöljük! 👋', style: AppTypography.eyebrow),
                                const SizedBox(height: 4),
                                Text(
                                  profile?.displayNameOrEmail ?? 'Felhasználó',
                                  style: AppTypography.titleLarge,
                                ),
                              ],
                            ),
                          ),
                          AppAvatar(
                            name: profile?.displayNameOrEmail,
                            imageUrl: profile?.avatarUrl,
                            size: 44,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Stat kártyák
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(title: 'Áttekintés'),
                        TutorialStep(
                          globalKey: _keyStats,
                          title: 'Statisztikák',
                          description: 'Az alkalmazás legfontosabb mutatói egy helyen.',
                          child: Row(
                            children: [
                              Expanded(child: _StatCard(
                                icon: LucideIcons.users,
                                label: 'Felhasználók',
                                value: '128',
                                color: AppColors.primary,
                              )),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _StatCard(
                                icon: LucideIcons.trendingUp,
                                label: 'Növekedés',
                                value: '+12%',
                                color: AppColors.secondary,
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(child: _StatCard(
                              icon: LucideIcons.checkCircle,
                              label: 'Teljesített',
                              value: '94',
                              color: AppColors.success,
                            )),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: _StatCard(
                              icon: LucideIcons.alertCircle,
                              label: 'Függőben',
                              value: '7',
                              color: AppColors.warning,
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Gyors műveletek
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(title: 'Gyors műveletek'),
                        AppCard(
                          child: Column(
                            children: [
                              SettingsListTile(
                                icon: LucideIcons.plus,
                                title: 'Új elem hozzáadása',
                                subtitle: 'Projekt adatok bővítése',
                                iconColor: AppColors.primary,
                                onTap: () {},
                              ),
                              Divider(color: AppColors.divider, height: 1),
                              SettingsListTile(
                                icon: LucideIcons.barChart2,
                                title: 'Riport megtekintése',
                                subtitle: 'Heti összefoglaló',
                                iconColor: AppColors.secondary,
                                onTap: () {},
                              ),
                              Divider(color: AppColors.divider, height: 1),
                              SettingsListTile(
                                icon: LucideIcons.share2,
                                title: 'Megosztás',
                                subtitle: 'Adatok exportálása',
                                iconColor: AppColors.accent,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Legutóbbi tevékenység (dummy)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(title: 'Legutóbbi tevékenység'),
                        ...List.generate(4, (i) {
                          final items = [
                            ('Új felhasználó regisztrált', 'Péter Kovács', '2p'),
                            ('Feladat teljesítve', '#42 Implementáció', '15p'),
                            ('Hiba javítva', 'Auth token lejárat', '1ó'),
                            ('Riport elkészült', 'Május havi összesítő', '3ó'),
                          ];
                          final item = items[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              onTap: () {},
                              child: AppListTile(
                                title: item.$1,
                                subtitle: item.$2,
                                showChevron: false,
                                trailing: Text(item.$3,
                                    style: AppTypography.bodySmall),
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(LucideIcons.activity,
                                      size: 16, color: AppColors.primary),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.titleLarge.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
