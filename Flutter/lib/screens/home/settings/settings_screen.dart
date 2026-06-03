import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/components/components.dart';
import '../../../core/theme/app_theme.dart';
import '../../../blocs/session/session_cubit.dart';
import '../../../blocs/session/session_state.dart';
import '../../../blocs/translation/translation_cubit.dart';
import '../../../core/translation_extension.dart';
import '../../../widgets/tutorial/tutorial_controller.dart'; // [M8]


// ============================================================
// SettingsScreen – Tab 4
// ============================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionCubit>().state;
    final profile =
        state is SessionLoggedIn ? state.profile : null;

    final langState = context.watch<TranslationCubit>().state;
    final langCode = langState is TranslationLoaded ? langState.currentLang : 'hu';
    final langName = langCode == 'hu' ? 'Magyar' : langCode == 'en' ? 'English' : 'Deutsch';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Beállítások')),
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
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),

          // Fiók beállítások
          const AppSectionHeader(title: 'Fiók'),
          AppCard(
            child: Column(
              children: [
                SettingsListTile(
                  icon: LucideIcons.user,
                  title: 'Profil szerkesztése',
                  subtitle: 'Név, avatar módosítása',
                  onTap: () {},
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.lock,
                  title: 'Jelszó módosítása',
                  onTap: () => _changePassword(context),
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.bell,
                  title: 'Értesítések',
                  subtitle: 'Push értesítések kezelése',
                  onTap: () {},
                ),
              ],
            ),
          ),

          // App beállítások
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
                  icon: LucideIcons.globe,
                  title: 'Nyelv',
                  subtitle: langName,
                  onTap: () => _changeLanguage(context),
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.shieldCheck,
                  title: 'Adatvédelem',
                  onTap: () => _showDocumentDialog(context, 'privacy'),
                ),
              ],
            ),
          ),

          // Tutorial [M8]
          const AppSectionHeader(title: 'Tutorial'),
          AppCard(
            child: SettingsListTile(
              icon: LucideIcons.graduationCap,
              title: 'Tutorialok újraindítása',
              subtitle: 'Az összes képernyő-tutorial törlése',
              onTap: () => _resetTutorials(context),
            ),
          ),

          // Alkalmazásról
          const AppSectionHeader(title: 'Névjegy'),
          AppCard(
            child: Column(
              children: [
                // Verzió – package_info_plus-ból dinamikusan
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (_, snap) => SettingsListTile(
                    icon: LucideIcons.info,
                    title: 'Verzió',
                    subtitle: snap.hasData
                        ? '${snap.data!.version} (build ${snap.data!.buildNumber})'
                        : '…',
                  ),
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.fileText,
                  title: 'Felhasználási feltételek',
                  onTap: () => _showDocumentDialog(context, 'terms'),
                ),
                Divider(color: AppColors.divider, height: 1),
                SettingsListTile(
                  icon: LucideIcons.shield,
                  title: 'Adatvédelmi nyilatkozat',
                  onTap: () => _showDocumentDialog(context, 'privacy'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Kijelentkezés
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

  // [M8] Tutorial állapotok törlése
  Future<void> _resetTutorials(BuildContext context) async {
    await TutorialController.resetAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(LucideIcons.graduationCap, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Tutorialok visszaállítva! Következő megnyitáskor újra láthatók.'),
          ]),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
            child: const Text('Mégsem'),
          ),
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

  void _changePassword(BuildContext context) {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Jelszó módosítása'),
              content: TextField(
                controller: passwordCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Új jelszó',
                  labelStyle: TextStyle(color: Colors.white54),
                  hintText: 'Legalább 6 karakter',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Mégsem'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final password = passwordCtrl.text.trim();
                          if (password.isEmpty || password.length < 6) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('A jelszónak legalább 6 karakterből kell állnia!')),
                              );
                            }
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(password: password),
                            );
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Jelszó sikeresen megváltoztatva!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Hiba: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Módosítás'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _changeLanguage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nyelv kiválasztása'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Magyar 🇭🇺', style: TextStyle(color: Colors.white)),
              onTap: () => _updateLanguage(context, 'hu', ctx),
            ),
            ListTile(
              title: const Text('English 🇬🇧', style: TextStyle(color: Colors.white)),
              onTap: () => _updateLanguage(context, 'en', ctx),
            ),
            ListTile(
              title: const Text('Deutsch 🇩🇪', style: TextStyle(color: Colors.white)),
              onTap: () => _updateLanguage(context, 'de', ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateLanguage(BuildContext context, String code, BuildContext dialogCtx) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client
            .from('user_profiles')
            .update({'language': code})
            .eq('id', uid);
      }
      
      if (context.mounted) {
        final translationCubit = context.read<TranslationCubit>();
        final sessionCubit = context.read<SessionCubit>();
        await translationCubit.loadTranslations(code);
        sessionCubit.reloadProfile();
      }
      
      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nyelv sikeresen megváltoztatva!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showDocumentDialog(BuildContext context, String docId) async {
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
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
}
