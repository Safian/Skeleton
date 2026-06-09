import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../blocs/session/session_cubit.dart';
import '../../../blocs/session/session_state.dart';

// ============================================================
// Admin SettingsScreen
// ============================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state   = context.watch<SessionCubit>().state;
    final profile = state is SessionLoggedIn ? state.profile : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Profil kártya
          if (profile != null)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    AppAvatar(
                      name: profile.displayNameOrEmail,
                      imageUrl: profile.avatarUrl,
                      size: 56,
                      color: AppColors.error.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.displayNameOrEmail,
                              style: AppTypography.titleSmall),
                          const SizedBox(height: 4),
                          Text(profile.email,
                              style: AppTypography.bodySmall),
                          const SizedBox(height: 6),
                          AppBadge(
                            label: profile.role,
                            variant: AppBadgeVariant.error,
                            icon: LucideIcons.shieldCheck,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const AppSectionHeader(title: 'Admin eszközök'),
          AppCard(
            child: Column(
              children: [
                SettingsListTile(
                  icon: LucideIcons.database,
                  title: 'Adatbázis',
                  subtitle: 'Supabase Studio megnyitása',
                  onTap: () {},
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.activity,
                  title: 'Rendszer naplók',
                  subtitle: 'Hibakeresés és monitoring',
                  onTap: () {},
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.bell,
                  title: 'Értesítések',
                  onTap: () {},
                ),
              ],
            ),
          ),

          const AppSectionHeader(title: 'Névjegy'),
          AppCard(
            child: Column(
              children: [
                SettingsListTile(
                  icon: LucideIcons.info,
                  title: 'Admin verzió',
                  subtitle: '1.0.0',
                  showChevron: false,
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.code2,
                  title: 'Skeleton App',
                  subtitle: 'Flutter + Supabase + BLoC',
                  showChevron: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: 'Kijelentkezés',
            variant: AppButtonVariant.danger,
            icon: LucideIcons.logOut,
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Kijelentkezés'),
        content: const Text('Biztosan ki szeretnél jelentkezni?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mégsem')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SessionCubit>().signOut();
            },
            child: Text('Kijelentkezés',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
