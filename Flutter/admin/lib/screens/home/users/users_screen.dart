import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../blocs/users/users_cubit.dart';
import '../../../blocs/users/users_state.dart';
import '../../../repositories/invitation_repository.dart';
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

  void _showInviteSheet(BuildContext context) {
    final emailCtrl = TextEditingController();
    final noteCtrl  = TextEditingController();
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg, right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Icon(LucideIcons.userPlus, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Admin meghívó küldése', style: AppTypography.titleSmall),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: emailCtrl,
                label: 'Email cím',
                hint: 'admin@example.com',
                prefixIcon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: noteCtrl,
                label: 'Megjegyzés (opcionális)',
                hint: 'pl. Marketing csapat',
                prefixIcon: LucideIcons.messageSquare,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: sending ? 'Küldés...' : 'Meghívó küldése',
                icon: LucideIcons.send,
                isLoading: sending,
                onTap: sending ? null : () async {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty) return;
                  setSt(() => sending = true);
                  try {
                    await InvitationRepository().sendInvitation(
                      email: email,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    );
                    if (sheetCtx.mounted) {
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Meghívó elküldve: $email'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setSt(() => sending = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Hiba: $e'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteSheet(context),
        icon: const Icon(LucideIcons.userPlus),
        label: const Text('Meghívó'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
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
