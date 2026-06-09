import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../blocs/session/session_cubit.dart';
import '../../../blocs/session/session_state.dart';
import '../../../blocs/translation/translation_cubit.dart';
import '../../../core/translation_extension.dart';
import 'edit_profile_screen.dart';
import '../../../services/tutorial_service.dart'; // [M4.2]

// ============================================================
// SettingsScreen – Tab 4
// ============================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  // ── [M4.2] Tutorial reset ───────────────────────────────────────

  Future<void> _resetTutorials() async {
    await TutorialService.instance.resetAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Minden tutorial visszaállítva!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ── Navigate to EditProfileScreen ────────────────────────────

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  // ── Sign out ─────────────────────────────────────────────────

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Kijelentkezés'),
        content: const Text('Biztosan ki szeretnél jelentkezni?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégsem'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SessionCubit>().signOut();
            },
            child: Text('Kijelentkezés', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Password change ──────────────────────────────────────────

  void _changePassword() {
    final state = context.read<SessionCubit>().state;
    final email = state is SessionLoggedIn ? state.profile.email : '';
    showDialog(
      context: context,
      builder: (_) => _PasswordDialog(userEmail: email),
    );
  }

  // ── Language ─────────────────────────────────────────────────

  void _changeLanguage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nyelv kiválasztása'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangTile(code: 'hu', label: 'Magyar 🇭🇺', dialogCtx: ctx),
            _LangTile(code: 'en', label: 'English 🇬🇧', dialogCtx: ctx),
            _LangTile(code: 'de', label: 'Deutsch 🇩🇪', dialogCtx: ctx),
          ],
        ),
      ),
    );
  }

  // ── Legal documents ──────────────────────────────────────────

  Future<void> _showDocumentDialog(String docId) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<dynamic>(
        future: Supabase.instance.client
            .from('legal_documents')
            .select()
            .eq('id', docId)
            .eq('is_active', true)
            .maybeSingle(),
        builder: (ctx2, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              content: const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Hiba'),
              content: const Text('Nem sikerült betölteni a dokumentumot.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('OK'),
                ),
              ],
            );
          }
          final data = snapshot.data as Map;
          final titleLocales = data['title_locales'] as Map? ?? {};
          final contentLocales = data['content_locales'] as Map? ?? {};

          String lang = 'hu';
          try {
            lang = context.currentLang;
          } catch (_) {}

          final title = titleLocales[lang] ?? titleLocales['hu'] ?? docId;
          final content = contentLocales[lang] ?? contentLocales['hu'] ?? '';

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 500,
              height: 500,
              child: SingleChildScrollView(
                child: HtmlPreviewWidget(htmlText: content),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Bezárás'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionCubit>().state;
    final profile = state is SessionLoggedIn ? state.profile : null;

    final langState = context.watch<TranslationCubit>().state;
    final langCode = langState is TranslationLoaded ? langState.currentLang : 'hu';
    final langName = switch (langCode) {
      'en' => 'English 🇬🇧',
      'de' => 'Deutsch 🇩🇪',
      _ => 'Magyar 🇭🇺',
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Beállítások')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Profil kártya ────────────────────────────────────
          if (profile != null)
            AppCard(
              child: InkWell(
                onTap: _openEditProfile,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      AppAvatar(
                        name: profile.displayNameOrEmail,
                        imageUrl: profile.avatarUrl,
                        size: 56,
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
                              variant: AppBadgeVariant.primary,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.pencil, size: 18),
                        onPressed: _openEditProfile,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Fiók ─────────────────────────────────────────────
          const AppSectionHeader(title: 'Fiók'),
          AppCard(
            child: Column(
              children: [
                // Nyelv – 2. sor a Fiók szekciójában
                SettingsListTile(
                  icon: LucideIcons.globe,
                  title: 'Nyelv',
                  subtitle: langName,
                  onTap: _changeLanguage,
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.lock,
                  title: 'Jelszó módosítása',
                  onTap: _changePassword,
                ),
                Divider(color: AppColors.divider, height: 1),
                // Értesítések – switch
                SettingsListTile(
                  icon: LucideIcons.bell,
                  title: 'Értesítések',
                  subtitle: _notificationsEnabled ? 'Bekapcsolva' : 'Kikapcsolva',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _notificationsEnabled = val),
                  ),
                ),
              ],
            ),
          ),

          // ── Alkalmazás ────────────────────────────────────────
          const AppSectionHeader(title: 'Alkalmazás'),
          AppCard(
            child: Column(
              children: [
                SettingsListTile(
                  icon: LucideIcons.palette,
                  title: 'Megjelenés',
                  subtitle: 'Téma, színek',
                  onTap: () {},
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.helpCircle,
                  title: 'Tutorialok újraindítása',
                  subtitle: 'Képernyős útmutatók visszaállítása',
                  onTap: _resetTutorials,
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.fileText,
                  title: 'Felhasználási feltételek',
                  onTap: () => _showDocumentDialog('terms'),
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.shieldCheck,
                  title: 'Adatvédelmi nyilatkozat',
                  onTap: () => _showDocumentDialog('privacy'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Kijelentkezés ─────────────────────────────────────
          AppButton(
            label: 'Kijelentkezés',
            variant: AppButtonVariant.danger,
            icon: LucideIcons.logOut,
            onTap: _confirmSignOut,
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Verzió – az oldal alján ───────────────────────────
          Text(
            'v1.0.0',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.3),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ============================================================
// _LangTile – nyelvválasztó listelem (dialógusban)
// ============================================================

class _LangTile extends StatelessWidget {
  final String code;
  final String label;
  final BuildContext dialogCtx;

  const _LangTile({
    required this.code,
    required this.label,
    required this.dialogCtx,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () => _updateLanguage(context, code),
    );
  }

  Future<void> _updateLanguage(BuildContext context, String code) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client
            .from('user_profiles')
            .update({'language': code})
            .eq('id', uid);
      }
      if (context.mounted) {
        await context.read<TranslationCubit>().loadTranslations(code);
        context.read<SessionCubit>().reloadProfile();
      }
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nyelv sikeresen megváltoztatva!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ============================================================
// _PasswordDialog – email reset VAGY jelenlegi+új jelszó
// ============================================================

class _PasswordDialog extends StatefulWidget {
  final String userEmail;

  const _PasswordDialog({required this.userEmail});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  // 0 = email reset, 1 = manual change
  int _mode = 0;

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _currentVisible = false;
  bool _newVisible = false;

  bool _isSaving = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Email reset ──────────────────────────────────────────────

  Future<void> _sendResetEmail() async {
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        widget.userEmail,
      );
      if (mounted) setState(() { _isSaving = false; _emailSent = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Manual change ────────────────────────────────────────────

  Future<void> _changeManual() async {
    final current = _currentCtrl.text.trim();
    final newPass = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty) {
      _showError('Add meg a jelenlegi jelszavadat!');
      return;
    }
    if (newPass.length < 8) {
      _showError('Az új jelszónak legalább 8 karakterből kell állnia!');
      return;
    }
    // If new password is hidden, require confirmation
    if (!_newVisible && newPass != confirm) {
      _showError('A két jelszó nem egyezik!');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Re-authenticate with current password first
      await Supabase.instance.client.auth.signInWithPassword(
        email: widget.userEmail,
        password: current,
      );
      // Then update password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jelszó sikeresen megváltoztatva!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Hiba: ${e.toString().contains('Invalid login') ? 'Hibás jelenlegi jelszó!' : e}');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Jelszó módosítása'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode toggle
            _ModeToggle(
              selected: _mode,
              onChanged: (v) => setState(() { _mode = v; _emailSent = false; }),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Email reset mode ─────────────────────────────
            if (_mode == 0) ...[
              if (_emailSent) ...[
                const Icon(LucideIcons.mailCheck, size: 40, color: Colors.green),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Visszaállítási linket küldtük a következő email-re:\n${widget.userEmail}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ] else ...[
                Text(
                  'Egy jelszó-visszaállítási linket küldünk a következő email-re:\n${widget.userEmail}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ],

            // ── Manual change mode ───────────────────────────
            if (_mode == 1) ...[
              // Current password
              TextField(
                controller: _currentCtrl,
                obscureText: !_currentVisible,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Jelenlegi jelszó',
                  labelStyle: const TextStyle(color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _currentVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                      color: Colors.white38,
                    ),
                    onPressed: () => setState(() => _currentVisible = !_currentVisible),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // New password
              TextField(
                controller: _newCtrl,
                obscureText: !_newVisible,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Új jelszó',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'Legalább 6 karakter',
                  hintStyle: const TextStyle(color: Colors.white24),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _newVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                      color: Colors.white38,
                    ),
                    onPressed: () => setState(() => _newVisible = !_newVisible),
                  ),
                ),
              ),
              // Confirm field – csak ha az új jelszó nem látható
              if (!_newVisible) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Új jelszó megerősítése',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Mégsem'),
        ),
        if (_mode == 0 && !_emailSent)
          TextButton(
            onPressed: _isSaving ? null : _sendResetEmail,
            child: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Email küldése'),
          ),
        if (_mode == 0 && _emailSent)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bezárás'),
          ),
        if (_mode == 1)
          TextButton(
            onPressed: _isSaving ? null : _changeManual,
            child: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Módosítás'),
          ),
      ],
    );
  }
}

// ============================================================
// _ModeToggle – email reset / kézi váltó
// ============================================================

class _ModeToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _ModeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _tab(context, 0, LucideIcons.mail, 'Email reset'),
          _tab(context, 1, LucideIcons.keyRound, 'Jelszó csere'),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int idx, IconData icon, String label) {
    final active = selected == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : Colors.white38),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
