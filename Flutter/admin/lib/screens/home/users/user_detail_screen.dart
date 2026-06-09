import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../blocs/users/users_cubit.dart';
import '../../../blocs/users/users_state.dart';

// ============================================================
// UserDetailScreen – felhasználó részletes nézet + role kezelés
// ============================================================

class UserDetailScreen extends StatelessWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UsersCubit, UsersState>(
      builder: (context, state) {
        final user = state is UsersLoaded
            ? state.users.where((u) => u.id == userId).firstOrNull
            : null;

        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Részletek')),
            body: const AppLoadingIndicator(),
          );
        }

        return _UserDetailView(user: user, isUpdating: state is UsersUpdating);
      },
    );
  }
}

class _UserDetailView extends StatelessWidget {
  final UserProfile user;
  final bool isUpdating;

  const _UserDetailView({required this.user, required this.isUpdating});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Felhasználó'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profil fejléc
            AppCard(
              child: Row(
                children: [
                  AppAvatar(
                    name: user.displayNameOrEmail,
                    imageUrl: user.avatarUrl,
                    size: 60,
                    color: user.role == 'admin'
                        ? AppColors.error.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.15),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayNameOrEmail,
                            style: AppTypography.titleMedium),
                        if (user.displayName != null)
                          Text(user.email, style: AppTypography.bodySmall),
                        const SizedBox(height: 6),
                        AppBadge(
                          label: user.role,
                          variant: user.role == 'admin'
                              ? AppBadgeVariant.error
                              : AppBadgeVariant.neutral,
                          icon: user.role == 'admin'
                              ? LucideIcons.shieldCheck
                              : LucideIcons.user,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Meta adatok
            const AppSectionHeader(title: 'Adatok'),
            AppCard(
              child: Column(
                children: [
                  _Row(icon: LucideIcons.fingerprint,
                      label: 'ID', value: user.id),
                  Divider(color: AppColors.divider, height: 1),
                  _Row(icon: LucideIcons.mail,
                      label: 'Email', value: user.email),
                  Divider(color: AppColors.divider, height: 1),
                  _Row(icon: LucideIcons.calendar,
                      label: 'Regisztráció',
                      value: _fmtDate(user.createdAt)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Szerepkör kezelés
            const AppSectionHeader(title: 'Szerepkör módosítása'),
            AppCard(
              child: Column(
                children: [
                  _RoleTile(
                    role: 'user',
                    label: 'Felhasználó',
                    subtitle: 'Normál hozzáférés',
                    icon: LucideIcons.user,
                    current: user.role,
                    isUpdating: isUpdating,
                    onSelect: (r) =>
                        _confirmRoleChange(context, user, r),
                  ),
                  Divider(color: AppColors.divider, height: 1),
                  _RoleTile(
                    role: 'admin',
                    label: 'Adminisztrátor',
                    subtitle: 'Teljes hozzáférés',
                    icon: LucideIcons.shieldCheck,
                    current: user.role,
                    isUpdating: isUpdating,
                    color: AppColors.error,
                    onSelect: (r) =>
                        _confirmRoleChange(context, user, r),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  void _confirmRoleChange(
      BuildContext context, UserProfile user, String newRole) {
    if (user.role == newRole) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Szerepkör módosítása'),
        content: Text(
          '${user.displayNameOrEmail} szerepköre: '
          '"${user.role}" → "$newRole"\n\nBiztosan módosítod?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégsem'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<UsersCubit>().updateRole(user.id, newRole);
            },
            child: Text('Módosítás',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgetek ───────────────────────────────────────────

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: AppColors.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.bodySmall)),
          Flexible(
            child: Text(value,
                style: AppTypography.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final String role;
  final String label;
  final String subtitle;
  final IconData icon;
  final String current;
  final bool isUpdating;
  final Color? color;
  final ValueChanged<String> onSelect;

  const _RoleTile({
    required this.role,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.current,
    required this.isUpdating,
    required this.onSelect,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == role;
    final c = color ?? AppColors.primary;

    return AppListTile(
      title: label,
      subtitle: subtitle,
      showChevron: false,
      onTap: isUpdating ? null : () => onSelect(role),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? c.withValues(alpha: 0.2)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        ),
        child: Icon(icon, size: 18,
            color: isSelected ? c : AppColors.onSurface.withValues(alpha: 0.5)),
      ),
      trailing: isUpdating && isSelected
          ? SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary))
          : isSelected
              ? Icon(LucideIcons.checkCircle, size: 20, color: c)
              : null,
    );
  }
}
