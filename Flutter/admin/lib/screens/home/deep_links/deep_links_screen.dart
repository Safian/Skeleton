import 'package:skeleton_shared/skeleton_shared.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../repositories/admin_repository.dart';

// ============================================================
// DeepLinksScreen – admin felület az iOS/Android deep link
// konfigurációhoz (AASA, AssetLinks, URL leképezések)
// ============================================================

class DeepLinksScreen extends StatefulWidget {
  const DeepLinksScreen({super.key});

  @override
  State<DeepLinksScreen> createState() => _DeepLinksScreenState();
}

class _DeepLinksScreenState extends State<DeepLinksScreen> {
  final _repo = AdminRepository();

  // JSON editors
  final _aasaCtrl        = TextEditingController();
  final _assetlinksCtrl  = TextEditingController();
  bool _loadingSettings  = true;
  bool _savingAasa       = false;
  bool _savingAssetlinks = false;

  // URL mappings
  List<Map<String, String>> _mappings = [];
  // Egy tuple per sor: (path, action, description) controller
  List<(TextEditingController, TextEditingController, TextEditingController)> _mappingCtrls = [];
  bool _savingMappings = false;

  // Base URL a .well-known ellenőrzéshez (app_settings → app_base_url)
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _aasaCtrl.dispose();
    _assetlinksCtrl.dispose();
    _disposeMappingControllers();
    super.dispose();
  }

  void _disposeMappingControllers() {
    for (final g in _mappingCtrls) {
      g.$1.dispose();
      g.$2.dispose();
      g.$3.dispose();
    }
    _mappingCtrls = [];
  }

  void _rebuildMappingControllers() {
    _disposeMappingControllers();
    _mappingCtrls = _mappings.map((m) => (
      TextEditingController(text: m['path']        ?? ''),
      TextEditingController(text: m['action']      ?? ''),
      TextEditingController(text: m['description'] ?? ''),
    )).toList();
  }

  Future<void> _loadSettings() async {
    setState(() => _loadingSettings = true);
    try {
      final rows = await _repo.fetchAppSettings();
      final aasa = rows.firstWhere(
        (r) => r['id'] == 'deeplink_aasa',
        orElse: () => {'value': ''},
      )['value'] as String? ?? '';
      final assetlinks = rows.firstWhere(
        (r) => r['id'] == 'deeplink_assetlinks',
        orElse: () => {'value': ''},
      )['value'] as String? ?? '';
      final mappingsRaw = rows.firstWhere(
        (r) => r['id'] == 'deeplink_url_mappings',
        orElse: () => {'value': '[]'},
      )['value'] as String? ?? '[]';

      // Base URL a .well-known ellenőrzéshez:
      // 1. app_settings → app_base_url
      // 2. fallback: SUPABASE_URL a .env-ből
      var rawBase = rows.firstWhere(
        (r) => r['id'] == 'app_base_url',
        orElse: () => {'value': ''},
      )['value'] as String? ?? '';
      if (rawBase.isEmpty) rawBase = dotenv.env['SUPABASE_URL'] ?? '';
      if (rawBase.isNotEmpty && !rawBase.startsWith('http')) {
        rawBase = 'https://$rawBase';
      }

      _aasaCtrl.text = aasa;
      _assetlinksCtrl.text = assetlinks;
      _baseUrl = rawBase;

      try {
        final decoded = (jsonDecode(mappingsRaw) as List).cast<Map<String, dynamic>>();
        _mappings = decoded.map((m) => {
          'path':        m['path']?.toString()        ?? '',
          'action':      m['action']?.toString()      ?? '',
          'description': m['description']?.toString() ?? '',
        }).toList();
      } catch (_) {
        _mappings = [];
      }
      // Controllereket újraépítjük a betöltött mappings alapján
      _rebuildMappingControllers();
    } catch (e) {
      _snack('Betöltési hiba: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  // ── Save helpers ────────────────────────────────────────────

  Future<void> _saveAasa() async {
    final v = _aasaCtrl.text.trim();
    if (!_validateJson(v, 'AASA')) return;
    setState(() => _savingAasa = true);
    try {
      await _repo.updateAppSetting('deeplink_aasa', v,
          'Apple App Site Association JSON');
      if (mounted) _snack('AASA mentve ✓');
    } catch (e) {
      if (mounted) _snack('Hiba: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingAasa = false);
    }
  }

  Future<void> _saveAssetlinks() async {
    final v = _assetlinksCtrl.text.trim();
    if (!_validateJson(v, 'AssetLinks')) return;
    setState(() => _savingAssetlinks = true);
    try {
      await _repo.updateAppSetting('deeplink_assetlinks', v,
          'Android Digital Asset Links JSON');
      if (mounted) _snack('AssetLinks mentve ✓');
    } catch (e) {
      if (mounted) _snack('Hiba: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingAssetlinks = false);
    }
  }

  Future<void> _saveMappings() async {
    setState(() => _savingMappings = true);
    try {
      await _repo.updateAppSetting(
        'deeplink_url_mappings',
        jsonEncode(_mappings),
        'Deep link URL path → action mappings',
      );
      if (mounted) _snack('Leképezések mentve ✓');
    } catch (e) {
      if (mounted) _snack('Hiba: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingMappings = false);
    }
  }

  bool _validateJson(String value, String label) {
    try {
      jsonDecode(value);
      return true;
    } catch (_) {
      _snack('Érvénytelen JSON — $label', error: true);
      return false;
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : Colors.teal.shade600,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingSettings) {
      return const Center(child: CircularProgressIndicator());
    }

    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadSettings,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── Header ──────────────────────────────────────
            Row(children: [
              Icon(LucideIcons.link, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Deep Link konfiguráció', style: AppTypography.titleMedium),
            ]),
            const SizedBox(height: 4),
            Text(
              'iOS Universal Links és Android App Links beállítása, valamint '
              'URL útvonal → akció leképezések kezelése.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Live státusz ─────────────────────────────────
            _WellKnownStatus(baseUrl: _baseUrl),
            const SizedBox(height: AppSpacing.lg),

            // ── AASA + AssetLinks ────────────────────────────
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildAasaCard()),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _buildAssetlinksCard()),
                ],
              )
            else ...[
              _buildAasaCard(),
              const SizedBox(height: AppSpacing.md),
              _buildAssetlinksCard(),
            ],

            const SizedBox(height: AppSpacing.lg),

            // ── URL Mappings ─────────────────────────────────
            _buildMappingsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAasaCard() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.smartphone, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text('iOS — Apple App Site Association',
                  style: AppTypography.titleSmall),
            ]),
            const SizedBox(height: 4),
            Text('Forrás: /.well-known/apple-app-site-association',
                style: AppTypography.bodySmall.copyWith(
                    color: Colors.white38, fontSize: 11)),
            const SizedBox(height: AppSpacing.md),
            _jsonEditor(_aasaCtrl, '{ "applinks": { ... } }'),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: _savingAasa ? 'Mentés...' : 'AASA mentése',
              icon: LucideIcons.save,
              isLoading: _savingAasa,
              onTap: _savingAasa ? null : _saveAasa,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetlinksCard() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.smartphone, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text('Android — Digital Asset Links',
                  style: AppTypography.titleSmall),
            ]),
            const SizedBox(height: 4),
            Text('Forrás: /.well-known/assetlinks.json',
                style: AppTypography.bodySmall.copyWith(
                    color: Colors.white38, fontSize: 11)),
            const SizedBox(height: AppSpacing.md),
            _jsonEditor(_assetlinksCtrl, '[ { "relation": [...], ... } ]'),
            const SizedBox(height: 4),
            Row(children: [
              Icon(LucideIcons.info, size: 11,
                  color: Colors.amber.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SHA256 fingerprint: keytool -list -v -keystore '
                  'android/app/upload-keystore.jks',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.amber.withValues(alpha: 0.6)),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: _savingAssetlinks ? 'Mentés...' : 'AssetLinks mentése',
              icon: LucideIcons.save,
              isLoading: _savingAssetlinks,
              onTap: _savingAssetlinks ? null : _saveAssetlinks,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingsCard() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(LucideIcons.mapPin, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('URL → Akció leképezések', style: AppTypography.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  _mappings.add({'path': '', 'action': '', 'description': ''});
                  _mappingCtrls.add((
                    TextEditingController(),
                    TextEditingController(),
                    TextEditingController(),
                  ));
                }),
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('Új sor'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'A kliens app ezek alapján vezeti az URL-eket a megfelelő '
              'képernyőre. Paraméter szintaxis: :nev (pl. /chat/:id).',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(children: const [
                Expanded(flex: 3,
                    child: Text('Útvonal',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 2,
                    child: Text('Akció',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 4,
                    child: Text('Leírás',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold))),
                SizedBox(width: 36),
              ]),
            ),

            if (_mappings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Még nincs leképezés — kattints az "Új sor"-ra.',
                      style: AppTypography.bodySmall),
                ),
              ),

            ...List.generate(_mappings.length, (i) {
              final pathCtrl = _mappingCtrls[i].$1;
              final actCtrl  = _mappingCtrls[i].$2;
              final descCtrl = _mappingCtrls[i].$3;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(flex: 3,
                      child: _mappingField(pathCtrl, '/path/:param',
                          (v) => _mappings[i]['path'] = v)),
                  const SizedBox(width: 8),
                  Expanded(flex: 2,
                      child: _mappingField(actCtrl, 'action_nev',
                          (v) => _mappings[i]['action'] = v)),
                  const SizedBox(width: 8),
                  Expanded(flex: 4,
                      child: _mappingField(descCtrl, 'Leírás...',
                          (v) => _mappings[i]['description'] = v)),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(LucideIcons.trash2,
                        size: 15, color: Colors.redAccent),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => setState(() {
                      _mappings.removeAt(i);
                      final g = _mappingCtrls.removeAt(i);
                      g.$1.dispose();
                      g.$2.dispose();
                      g.$3.dispose();
                    }),
                  ),
                ]),
              );
            }),

            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: _savingMappings ? 'Mentés...' : 'Leképezések mentése',
              icon: LucideIcons.save,
              isLoading: _savingMappings,
              onTap: _savingMappings ? null : _saveMappings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _jsonEditor(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      maxLines: 14,
      style: const TextStyle(
          fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.35),
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontFamily: 'monospace',
            fontSize: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1))),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _mappingField(TextEditingController ctrl, String hint,
      void Function(String) onChanged) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
    );
  }
}

// ── Well-known live státusz chip ─────────────────────────────────────────────

enum _WknState { idle, loading, ok, error }

class _WellKnownStatus extends StatefulWidget {
  final String baseUrl;
  const _WellKnownStatus({required this.baseUrl});

  @override
  State<_WellKnownStatus> createState() => _WellKnownStatusState();
}

class _WellKnownStatusState extends State<_WellKnownStatus> {
  _WknState _aasaState        = _WknState.idle;
  _WknState _assetlinksState  = _WknState.idle;
  int? _aasaCode, _assetlinksCode;

  // [path] egy relatív útvonal, pl. '/.well-known/apple-app-site-association'
  Future<void> _check(String path, bool isAasa) async {
    setState(() {
      if (isAasa) { _aasaState = _WknState.loading; _aasaCode = null; }
      else { _assetlinksState = _WknState.loading; _assetlinksCode = null; }
    });

    final base = widget.baseUrl.trimRight();
    if (base.isEmpty) {
      setState(() {
        if (isAasa) _aasaState = _WknState.error;
        else _assetlinksState = _WknState.error;
      });
      return;
    }

    try {
      final res = await http.get(Uri.parse('$base$path'))
          .timeout(const Duration(seconds: 8));
      setState(() {
        final code = res.statusCode;
        final ok   = code == 200;
        if (isAasa) { _aasaCode = code; _aasaState = ok ? _WknState.ok : _WknState.error; }
        else { _assetlinksCode = code; _assetlinksState = ok ? _WknState.ok : _WknState.error; }
      });
    } catch (_) {
      setState(() {
        if (isAasa) _aasaState = _WknState.error;
        else _assetlinksState = _WknState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live .well-known státusz', style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(child: _chip(
                'apple-app-site-association',
                _aasaState, _aasaCode,
                () => _check('/.well-known/apple-app-site-association', true),
              )),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _chip(
                'assetlinks.json',
                _assetlinksState, _assetlinksCode,
                () => _check('/.well-known/assetlinks.json', false),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, _WknState state, int? code, VoidCallback onTap) {
    final (color, icon) = switch (state) {
      _WknState.idle    => (Colors.white38,      LucideIcons.helpCircle),
      _WknState.loading => (Colors.amber,         LucideIcons.loaderCircle),
      _WknState.ok      => (Colors.tealAccent,    LucideIcons.checkCircle2),
      _WknState.error   => (Colors.redAccent,     LucideIcons.xCircle),
    };
    return GestureDetector(
      onTap: state == _WknState.loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          state == _WknState.loading
              ? SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color))
              : Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)),
                Text(
                  state == _WknState.idle
                      ? 'Kattints az ellenőrzéshez'
                      : state == _WknState.ok
                          ? 'Elérhető (HTTP $code)'
                          : state == _WknState.error
                              ? 'Hiba${code != null ? " ($code)" : ""}'
                              : 'Ellenőrzés...',
                  style: TextStyle(
                      fontSize: 10,
                      color: color.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.refreshCw,
              size: 12, color: color.withValues(alpha: 0.6)),
        ]),
      ),
    );
  }
}
