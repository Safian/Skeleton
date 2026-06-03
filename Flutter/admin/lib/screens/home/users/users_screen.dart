import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/components/components.dart';
import '../../../core/theme/app_theme.dart';
import '../../../blocs/users/users_cubit.dart';
import '../../../blocs/users/users_state.dart';
import '../../../models/user_profile.dart';
import 'user_detail_screen.dart';

// ============================================================
// UsersScreen – összes felhasználó listája, kereshetően
// ============================================================

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: Column(
        children: [
          // Keresőmező
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: AppTextField(
              label: '',
              hint: 'Keresés email vagy név alapján...',
              prefixIcon: LucideIcons.search,
              controller: _searchCtrl,
              onChanged: (q) => context.read<UsersCubit>().search(q),
            ),
          ),

          // Lista
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => context.read<UsersCubit>().refresh(),
              child: BlocBuilder<UsersCubit, UsersState>(
                builder: (context, state) {
                  return switch (state) {
                    UsersLoading() => const AppLoadingIndicator(),
                    UsersError() => CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            child: Center(
                              child: AppEmptyState(
                                icon: LucideIcons.circleX,
                                title: 'Hiba',
                                subtitle: state.message,
                                action: AppButton(
                                  label: 'Újrapróbálás',
                                  fullWidth: false,
                                  onTap: () => context.read<UsersCubit>().refresh(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    UsersLoaded() => () {
                        final users = state.filtered;
                        if (users.isEmpty) {
                          return CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverFillRemaining(
                                child: Center(
                                  child: AppEmptyState(
                                    icon: LucideIcons.userX,
                                    title: _searchCtrl.text.isNotEmpty
                                        ? 'Nincs találat'
                                        : 'Nincsenek felhasználók',
                                    subtitle: _searchCtrl.text.isNotEmpty
                                        ? 'Próbálj más keresési feltételt'
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: users.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) => _UserCard(user: users[i]),
                        );
                      }(),
                    _ => const AppLoadingIndicator(),
                  };
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Felhasználó kártya ────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final UserProfile user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<UsersCubit>(),
            child: UserDetailScreen(userId: user.id),
          ),
        ),
      ),
      child: AppListTile(
        title: user.displayNameOrEmail,
        subtitle: user.displayName != null ? user.email : null,
        leading: AppAvatar(
          name: user.displayNameOrEmail,
          imageUrl: user.avatarUrl,
          size: 40,
          color: user.role == 'admin'
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.15),
        ),
        badgeLabel: user.role,
        badgeVariant: user.role == 'admin'
            ? AppBadgeVariant.error
            : AppBadgeVariant.neutral,
        trailing: Text(
          _formatDate(user.createdAt),
          style: AppTypography.bodySmall,
        ),
        showChevron: false,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}
