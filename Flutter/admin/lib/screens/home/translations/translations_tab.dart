import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';


import '../../../core/theme/app_theme.dart';
import '../../../core/components/components.dart';
import '../../../blocs/admin/admin_cubit.dart';
import '../../../models/translation_entry.dart';
import '../../../blocs/translation/translation_cubit.dart';
import '../../../repositories/admin_repository.dart';

import '../../../core/translation_extension.dart';
import '../../../core/codebase_translations.dart';


class TranslationsTab extends StatefulWidget {
  const TranslationsTab({super.key});

  @override
  State<TranslationsTab> createState() => _TranslationsTabState();
}

class _TranslationsTabState extends State<TranslationsTab> {
  static String? _sessionApiKey;
  bool _isGeneratingLanguage = false;
  String _translationEditLang = 'en';
  String _translationSearchQuery = '';
  final _translationSearchCtrl = TextEditingController();
  int _translationPage = 0;
  static const int _translationPageSize = 30;

  static const _presetLanguages = [
    {'code': 'en', 'name': 'English',    'flag': '🇬🇧'},
    {'code': 'de', 'name': 'Deutsch',    'flag': '🇩🇪'},
    {'code': 'fr', 'name': 'Français',   'flag': '🇫🇷'},
    {'code': 'es', 'name': 'Español',    'flag': '🇪🇸'},
    {'code': 'it', 'name': 'Italiano',   'flag': '🇮🇹'},
    {'code': 'pl', 'name': 'Polski',     'flag': '🇵🇱'},
    {'code': 'ro', 'name': 'Română',     'flag': '🇷🇴'},
    {'code': 'cs', 'name': 'Čeština',   'flag': '🇨🇿'},
    {'code': 'sk', 'name': 'Slovenčina','flag': '🇸🇰'},
    {'code': 'hr', 'name': 'Hrvatski',  'flag': '🇭🇷'},
  ];


  @override
  void dispose() {
    _translationSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCubit, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is AdminError) {
          return Center(
            child: Text(state.message, style: const TextStyle(color: Colors.red)),
          );
        }
        if (state is! AdminLoaded) {
          return const SizedBox.shrink();
        }

        // Összefésülés a codebaseTranslations kulcsaival
        final mergedTranslations = List<TranslationEntry>.from(state.translations);
        final existingKeys = state.translations.map((t) => t.key).toSet();

        codebaseTranslations.forEach((key, fallbacks) {
          if (!existingKeys.contains(key)) {
            mergedTranslations.add(TranslationEntry(
              key: key,
              hu: fallbacks['hu'] ?? '',
              en: fallbacks['en'] ?? '',
              locales: const {},
            ));
          }
        });

        // Rendezés kulcs szerint
        mergedTranslations.sort((a, b) => a.key.compareTo(b.key));

        final query = _translationSearchQuery.toLowerCase().trim();
        final filtered = mergedTranslations.where((t) {
          if (query.isEmpty) return true;
          final keyMatch = t.key.toLowerCase().contains(query);
          final huMatch = t.hu.toLowerCase().contains(query);
          final transMatch = t.locales[_translationEditLang]?.toString().toLowerCase().contains(query) ?? false;
          final enMatch = t.en.toLowerCase().contains(query);
          return keyMatch || huMatch || transMatch || enMatch;
        }).toList();


        final totalPages = (filtered.length / _translationPageSize).ceil().clamp(1, 9999);
        final currentPage = _translationPage.clamp(0, totalPages - 1);
        final pageItems = filtered
            .skip(currentPage * _translationPageSize)
            .take(_translationPageSize)
            .toList();

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Language selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _translationEditLang,
                        dropdownColor: AppColors.surface,
                        icon: const Icon(LucideIcons.chevronDown, size: 16, color: Colors.white54),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                          DropdownMenuItem(value: 'de', child: Text('🇩🇪 Deutsch')),
                          DropdownMenuItem(value: 'hu', child: Text('🇭🇺 Magyar')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _translationEditLang = val;
                              _translationPage = 0;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  // AI Javítás – hiányzó fordítások pótlása az aktív nyelvhez
                  if (_translationEditLang != 'hu')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: _isGeneratingLanguage
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.wand2, size: 16),
                      label: Text('AI Javítás (${_flagForLang(_translationEditLang)})'),
                      onPressed: _isGeneratingLanguage
                          ? null
                          : () => _generateLanguageWithAi(_translationEditLang, missingOnly: true),
                    ),
                  // Új nyelv AI-val
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: _isGeneratingLanguage
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('Új nyelv AI-val'),
                    onPressed: _isGeneratingLanguage
                        ? null
                        : () => _showAddLanguageDialog(state),
                  ),
                  // Új fordítás
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Új fordítás'),
                    onPressed: () => _showTranslationEditDialog(null),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Search field
              AppTextField(
                label: '',
                hint: 'Keresés kulcs vagy szöveg alapján...',
                prefixIcon: LucideIcons.search,
                controller: _translationSearchCtrl,
                onChanged: (val) {
                  setState(() {
                    _translationSearchQuery = val;
                    _translationPage = 0;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Count info
              Text(
                '${filtered.length} fordítási kulcs • oldal ${currentPage + 1} / $totalPages',
                style: AppTypography.bodySmall.copyWith(color: Colors.white30),
              ),
              const SizedBox(height: AppSpacing.md),

              // Table / list
              Expanded(
                child: pageItems.isEmpty
                    ? const Center(child: Text('Nincs találat.'))
                    : ListView.builder(
                        itemCount: pageItems.length,
                        itemBuilder: (context, index) {
                          return _translationTile(pageItems[index]);
                        },
                      ),
              ),

              // Pagination
              if (totalPages > 1) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.chevronLeft),
                      onPressed: currentPage > 0
                          ? () => setState(() => _translationPage = currentPage - 1)
                          : null,
                    ),
                    Text('${currentPage + 1} / $totalPages', style: const TextStyle(color: Colors.white)),
                    IconButton(
                      icon: const Icon(LucideIcons.chevronRight),
                      onPressed: currentPage < totalPages - 1
                          ? () => setState(() => _translationPage = currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _translationTile(TranslationEntry entry) {
    final targetVal = _translationEditLang == 'hu'
        ? entry.hu
        : _translationEditLang == 'en'
            ? entry.en
            : entry.locales[_translationEditLang] as String? ?? '';

    final hasTranslation = targetVal.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      entry.key,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🇭🇺 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            entry.hu,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (_translationEditLang != 'hu') ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_flagForLang(_translationEditLang)} ', style: const TextStyle(fontSize: 14)),
                          Expanded(
                            child: Text(
                              targetVal,
                              style: TextStyle(
                                color: hasTranslation ? Colors.white70 : Colors.white24,
                                fontStyle: hasTranslation ? FontStyle.normal : FontStyle.italic,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.pencil, size: 16, color: Colors.white70),
                    onPressed: () => _showTranslationEditDialog(entry),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                    onPressed: () => _confirmDeleteTranslation(entry),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _flagForLang(String lang) {
    switch (lang) {
      case 'hu': return '🇭🇺';
      case 'en': return '🇬🇧';
      case 'de': return '🇩🇪';
      case 'fr': return '🇫🇷';
      case 'es': return '🇪🇸';
      case 'it': return '🇮🇹';
      case 'pl': return '🇵🇱';
      case 'ro': return '🇷🇴';
      case 'cs': return '🇨🇿';
      case 'sk': return '🇸🇰';
      case 'hr': return '🇭🇷';
      default: return '🏳️';
    }
  }

  // ── AI Language Generation ──────────────────────────────────────────────────

  void _showAddLanguageDialog(AdminLoaded state) {
    String selectedCode = 'en';
    String customCode = '';
    bool useCustom = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(LucideIcons.sparkles, color: AppColors.secondary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Új nyelv hozzáadása AI-val',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Az AI a meglévő magyar szövegeket automatikusan lefordítja a kiválasztott nyelvre, '
                  'és az összes fordítási kulcsot frissíti az adatbázisban.',
                  style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Célnyelv kiválasztása:',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetLanguages.map((l) {
                    final isSelected = !useCustom && selectedCode == l['code'];
                    return GestureDetector(
                      onTap: () => setLocal(() {
                        selectedCode = l['code']!;
                        useCustom = false;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.secondary.withValues(alpha: 0.15)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.secondary : Colors.white12,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l['flag']!, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              l['name']!,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white60,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Custom language code
                Row(
                  children: [
                    Checkbox(
                      value: useCustom,
                      onChanged: (v) => setLocal(() => useCustom = v ?? false),
                      fillColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected) ? AppColors.secondary : Colors.transparent,
                      ),
                      side: const BorderSide(color: Colors.white38),
                    ),
                    const Text('Egyéni kód:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        enabled: useCustom,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'pl. "fr", "es"',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                        ),
                        onChanged: (v) => customCode = v.trim().toLowerCase(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Az AI ${state.translations.length} fordítási kulcsot fog létrehozni. '
                          'Ez néhány másodpercet vehet igénybe.',
                          style: const TextStyle(color: Colors.amber, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mégsem', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('Fordítás generálása'),
              onPressed: () {
                final langCode = useCustom ? customCode : selectedCode;
                if (langCode.isEmpty) return;
                Navigator.pop(ctx);
                _generateLanguageWithAi(langCode);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateLanguageWithAi(String targetLang, {bool missingOnly = false}) async {
    setState(() => _isGeneratingLanguage = true);
    try {
      // A pre-login (offline) kulcsok beszúrása a DB-be, hogy az AI azokat is
      // lefordítsa – így a login / maintenance oldalak is megkapják az új nyelvet.
      await context
          .read<AdminRepository>()
          .seedMissingCodebaseTranslations(codebaseTranslations);

      final result = await Supabase.instance.client.functions.invoke(
        'translate-language',
        body: {'targetLang': targetLang, 'missingOnly': missingOnly},
      );
      final data = result.data as Map?;
      final count = data?['count'] ?? 0;
      final error = data?['error'] as String?;

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba a fordítás során: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        final label = missingOnly
            ? '$count hiányzó fordítás pótolva (${_flagForLang(targetLang)} $targetLang)!'
            : '$count fordítási kulcs sikeresen létrehozva (${_flagForLang(targetLang)} $targetLang)!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.check, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(label)),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        // Refresh both admin state and TranslationCubit
        context.read<AdminCubit>().initAdmin();
        await context.read<TranslationCubit>().loadTranslations(targetLang);
        setState(() {
          _translationEditLang = targetLang;
          _translationPage = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hálózati hiba: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingLanguage = false);
    }
  }

  void _showTranslationEditDialog(TranslationEntry? entry) {
    final keyCtrl = TextEditingController(text: entry?.key ?? '');
    final huCtrl = TextEditingController(text: entry?.hu ?? '');
    final enCtrl = TextEditingController(text: entry?.en ?? '');
    final deCtrl = TextEditingController(text: entry?.locales['de'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(entry == null ? 'Új kulcs felvétele' : 'Fordítás szerkesztése'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyCtrl,
                enabled: entry == null,
                decoration: const InputDecoration(labelText: 'Fordítási kulcs (pl. auth.login_btn)'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: huCtrl,
                      decoration: const InputDecoration(labelText: 'Magyar szöveg (HU 🇭🇺)'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Kitöltés AI-val (Gemini)',
                    icon: Icon(LucideIcons.sparkles, color: AppColors.secondary),
                    onPressed: () => _autoTranslate(huCtrl.text, enCtrl, deCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: enCtrl,
                decoration: const InputDecoration(labelText: 'Angol szöveg (EN 🇬🇧)'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deCtrl,
                decoration: const InputDecoration(labelText: 'Német szöveg (DE 🇩🇪)'),
                style: const TextStyle(color: Colors.white),
              ),

            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mégsem'),
          ),
          TextButton(
            onPressed: () {
              final key = keyCtrl.text.trim();
              final hu = huCtrl.text.trim();
              final en = enCtrl.text.trim();
              final de = deCtrl.text.trim();

              if (key.isEmpty || hu.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('A kulcs és a magyar szöveg megadása kötelező!')),
                );
                return;
              }

              final newEntry = TranslationEntry(
                key: key,
                hu: hu,
                en: en,
                locales: {'de': de},
              );

              if (entry == null) {
                context.read<AdminCubit>().createTranslation(newEntry);
              } else {
                context.read<AdminCubit>().updateTranslation(entry.key, newEntry);
              }
              
              // reload client-side translations immediately if current locale is loaded
              context.read<TranslationCubit>().loadTranslations(context.currentLang);

              Navigator.pop(ctx);
            },
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTranslation(TranslationEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Törlés megerősítése'),
        content: Text('Biztosan törölni szeretnéd a "${entry.key}" kulcsot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mégsem'),
          ),
          TextButton(
            onPressed: () {
              context.read<AdminCubit>().deleteTranslation(entry.key);
              // reload client-side translations immediately
              context.read<TranslationCubit>().loadTranslations(context.currentLang);
              Navigator.pop(ctx);
            },
            child: Text('Törlés', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _autoTranslate(String text, TextEditingController enCtrl, TextEditingController deCtrl) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kérlek írj be először magyar szöveget!')),
      );
      return;
    }

    String? apiKey;
    try {
      apiKey = dotenv.env['GEMINI_API_KEY'];
    } catch (_) {}

    if (apiKey == null || apiKey.isEmpty) {
      apiKey = await _promptApiKeyDialog();
    }

    if (apiKey == null || apiKey.trim().isEmpty) {
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Fordítás folyamatban az AI-val...'),
          ],
        ),
        duration: Duration(days: 1),
      ),
    );

    try {
      final translations = await _callGeminiTranslate(text: text, apiKey: apiKey);
      
      enCtrl.text = translations['en'] ?? '';
      deCtrl.text = translations['de'] ?? '';

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sikeres AI fordítás!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI fordítási hiba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _promptApiKeyDialog() async {
    if (_sessionApiKey != null && _sessionApiKey!.isNotEmpty) {
      return _sessionApiKey;
    }

    final keyCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Gemini API Kulcs Szükséges'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Az AI-val történő kitöltéshez meg kell adnod egy Gemini API kulcsot.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'API Kulcs',
                hintText: 'AIzaSy...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Mégsem'),
          ),
          TextButton(
            onPressed: () {
              final key = keyCtrl.text.trim();
              if (key.isNotEmpty) {
                _sessionApiKey = key;
                Navigator.pop(ctx, key);
              }
            },
            child: const Text('Rendben'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _callGeminiTranslate({
    required String text,
    required String apiKey,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      
      final prompt = 'Translate the following Hungarian text to English and German. Return ONLY a JSON object in this format: {"en": "English translation", "de": "German translation"}. Do not return markdown, do not write anything else, just the pure JSON. Text: "$text"';
      
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      });
      
      request.write(body);
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        
        final candidates = decoded['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('Nincs válasz a Gemini modelltől.');
        }
        
        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          throw Exception('Üres válasz érkezett.');
        }
        
        final textContent = parts[0]['text'] as String?;
        if (textContent == null || textContent.isEmpty) {
          throw Exception('A válasz szövege üres.');
        }
        
        String jsonStr = textContent.trim();
        if (jsonStr.contains('```')) {
          final start = jsonStr.indexOf('{');
          final end = jsonStr.lastIndexOf('}');
          if (start != -1 && end != -1) {
            jsonStr = jsonStr.substring(start, end + 1);
          }
        }
        
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        return {
          'en': parsed['en']?.toString() ?? '',
          'de': parsed['de']?.toString() ?? '',
        };
      } else {
        throw Exception('Gemini API hiba: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Kapcsolódási hiba: $e');
    } finally {
      client.close();
    }
  }
}

