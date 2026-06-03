import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/components/components.dart';
import '../../../core/theme/app_theme.dart';
import '../../../blocs/session/session_cubit.dart';
import '../../../blocs/session/session_state.dart';
import '../../../blocs/users/users_cubit.dart';
import '../../../blocs/users/users_state.dart';

// ============================================================
// Admin DashboardScreen – élő statisztikák
// ============================================================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionState = context.watch<SessionCubit>().state;
    final profile =
        sessionState is SessionLoggedIn ? sessionState.profile : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RadialBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => context.read<UsersCubit>().refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Admin Panel', style: AppTypography.eyebrow),
                              const SizedBox(height: 4),
                              Text('Dashboard', style: AppTypography.titleLarge),
                            ],
                          ),
                        ),
                        if (profile != null)
                          AppAvatar(
                            name: profile.displayNameOrEmail,
                            imageUrl: profile.avatarUrl,
                            size: 44,
                          ),
                      ],
                    ),
                  ),
                ),

                // Statisztika kártyák
                SliverToBoxAdapter(
                  child: BlocBuilder<UsersCubit, UsersState>(
                    builder: (context, state) {
                      if (state is UsersLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: AppLoadingIndicator(),
                        );
                      }
                      if (state is! UsersLoaded) {
                        return const SizedBox.shrink();
                      }
                      final stats = state.stats;
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppSectionHeader(title: 'Felhasználók'),
                            Row(children: [
                              Expanded(child: _StatCard(
                                icon: LucideIcons.users,
                                label: 'Összes',
                                value: '${stats.totalUsers}',
                                color: AppColors.primary,
                              )),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _StatCard(
                                icon: LucideIcons.userPlus,
                                label: 'Ma új',
                                value: '${stats.newUsersToday}',
                                color: AppColors.secondary,
                              )),
                            ]),
                            const SizedBox(height: AppSpacing.md),
                            Row(children: [
                              Expanded(child: _StatCard(
                                icon: LucideIcons.calendarDays,
                                label: '7 napos új',
                                value: '${stats.newUsersThisWeek}',
                                color: AppColors.accent,
                              )),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _StatCard(
                                icon: LucideIcons.shieldCheck,
                                label: 'Adminok',
                                value: '${state.users.where((u) => u.role == "admin").length}',
                                color: AppColors.error,
                              )),
                            ]),
                            const AppSectionHeader(title: 'Elemek'),
                            Row(children: [
                              Expanded(child: _StatCard(
                                icon: LucideIcons.list,
                                label: 'Összes elem',
                                value: '${stats.totalItems}',
                                color: AppColors.primary,
                              )),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _StatCard(
                                icon: LucideIcons.checkCircle,
                                label: 'Aktív elem',
                                value: '${stats.activeItems}',
                                color: AppColors.success,
                              )),
                            ]),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Legutóbbi felhasználók
                SliverToBoxAdapter(
                  child: BlocBuilder<UsersCubit, UsersState>(
                    builder: (context, state) {
                      if (state is! UsersLoaded || state.users.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final recent = state.users.take(5).toList();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Expanded(
                                  child: AppSectionHeader(
                                      title: 'Legutóbbi regisztrációk'),
                                ),
                              ],
                            ),
                            AppCard(
                              child: Column(
                                children: [
                                  for (int i = 0; i < recent.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                          color: AppColors.divider, height: 1),
                                    AppListTile(
                                      title: recent[i].displayNameOrEmail,
                                      subtitle: recent[i].email,
                                      leading: AppAvatar(
                                        name: recent[i].displayNameOrEmail,
                                        imageUrl: recent[i].avatarUrl,
                                        size: 36,
                                      ),
                                      badgeLabel: recent[i].role,
                                      badgeVariant: recent[i].role == 'admin'
                                          ? AppBadgeVariant.error
                                          : AppBadgeVariant.neutral,
                                      showChevron: false,
                                      trailing: Text(
                                        _timeAgo(recent[i].createdAt),
                                        style: AppTypography.bodySmall,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}n';
    if (diff.inHours > 0) return '${diff.inHours}ó';
    if (diff.inMinutes > 0) return '${diff.inMinutes}p';
    return 'Most';
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
          Text(value,
              style: AppTypography.titleLarge.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
