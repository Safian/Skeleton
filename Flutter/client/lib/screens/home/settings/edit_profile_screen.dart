import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../blocs/session/session_cubit.dart';
import '../../../blocs/session/session_state.dart';
import '../../../core/components/components.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// EditProfileScreen – Profil szerkesztése képernyő
// ============================================================

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<SessionCubit>().state;
    final profile = state is SessionLoggedIn ? state.profile : null;
    _nameCtrl = TextEditingController(text: profile?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Save display name ────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    setState(() => _isSaving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client
            .from('user_profiles')
            .update({'display_name': name.isEmpty ? null : name})
            .eq('id', uid);
        if (mounted) {
          await context.read<SessionCubit>().reloadProfile();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil sikeresen mentve!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Photo / AI placeholders ──────────────────────────────────

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature – hamarosan elérhető!')),
    );
  }

  // ── Delete account ───────────────────────────────────────────

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Fiók törlése',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Biztosan törölni szeretnéd a fiókodat?\n\nEz a művelet visszafordíthatatlan – minden adatod véglegesen törlésre kerül.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Mégsem'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _deleteAccount();
            },
            child: Text(
              'Fiók törlése',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    try {
      // TODO: Implement via Supabase edge function ('delete-account')
      // or a PostgreSQL RPC that deletes the user and all related data.
      // await Supabase.instance.client.functions.invoke('delete-account');
      if (mounted) {
        await context.read<SessionCubit>().signOut();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a törlés során: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionCubit>().state;
    final profile = state is SessionLoggedIn ? state.profile : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profil szerkesztése')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Avatar area ──────────────────────────────────────
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    AppAvatar(
                      name: profile?.displayNameOrEmail,
                      imageUrl: profile?.avatarUrl,
                      size: 96,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _showComingSoon('Fotó feltöltése'),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                          child: const Icon(LucideIcons.camera, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AvatarActionButton(
                      icon: LucideIcons.upload,
                      label: 'Feltöltés',
                      onTap: () => _showComingSoon('Fotó feltöltése'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _AvatarActionButton(
                      icon: LucideIcons.sparkles,
                      label: 'AI generálás',
                      onTap: () => _showComingSoon('AI avatar generálás'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Display name ─────────────────────────────────────
          const AppSectionHeader(title: 'Megjelenítési név'),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: TextField(
                controller: _nameCtrl,
                style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: profile?.email ?? 'Írd be a neved...',
                  hintStyle: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.35)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Save button ──────────────────────────────────────
          AppButton(
            label: 'Mentés',
            icon: LucideIcons.check,
            isLoading: _isSaving,
            onTap: _save,
          ),

          const SizedBox(height: AppSpacing.xl * 3),

          // ── Delete account ───────────────────────────────────
          Divider(color: AppColors.error.withValues(alpha: 0.2)),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Fiók törlése',
            variant: AppButtonVariant.danger,
            icon: LucideIcons.trash2,
            isLoading: _isDeleting,
            onTap: _confirmDeleteAccount,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ez a művelet visszafordíthatatlan.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.error.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ============================================================
// _AvatarActionButton – kis ikonos gomb az avatar szerkesztéshez
// ============================================================

class _AvatarActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AvatarActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.label.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
