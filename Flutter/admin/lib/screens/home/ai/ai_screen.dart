import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/ai_model.dart';
import '../../../repositories/admin_repository.dart';

// ============================================================
// AI Screen – model configuration + real cost statistics
// ============================================================

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _repo = AdminRepository();

  List<AiModel> _models = [];
  Map<String, dynamic> _costStats = {};
  List<Map<String, dynamic>> _gptLogs = [];
  bool _loading = true;
  String? _error;

  // Daily cost limit
  final _limitCtrl = TextEditingController();
  bool _savingLimit = false;
  bool _limitInitialized = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _repo.fetchAiModels(),
        _repo.fetchCostStats(),
        _repo.fetchGptLogs(limit: 50),
        _repo.getAppSetting('daily_api_cost_limit'),
      ]);
      _models    = results[0] as List<AiModel>;
      _costStats = results[1] as Map<String, dynamic>;
      _gptLogs   = results[2] as List<Map<String, dynamic>>;
      final setting = results[3] as Map<String, dynamic>?;
      if (!_limitInitialized) {
        _limitCtrl.text = setting?['value'] as String? ?? '5.0';
        _limitInitialized = true;
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─────────────────────── build ────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.triangleAlert, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Újra')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final gptToday  = (_costStats['gpt_cost_today']  as double?) ?? 0.0;
    final gptMonth  = (_costStats['gpt_cost_month']  as double?) ?? 0.0;
    final inTok     = (_costStats['input_tokens_month']  as int?) ?? 0;
    final outTok    = (_costStats['output_tokens_month'] as int?) ?? 0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Havi összköltség – nagy összesítő ───────────────────
          _buildMonthlySummary(gptMonth),
          const SizedBox(height: 24),

          // ── Napi / token statisztikák ────────────────────────────
          Row(
            children: [
              _statCard('Ma (OpenAI)', '\$${gptToday.toStringAsFixed(4)}',
                  LucideIcons.zap, Colors.blue),
              const SizedBox(width: 16),
              _statCard('Input tokenek/hó', _fmt(inTok),
                  LucideIcons.arrowUp, Colors.purple),
              const SizedBox(width: 16),
              _statCard('Output tokenek/hó', _fmt(outTok),
                  LucideIcons.arrowDown, Colors.teal),
            ],
          ),
          const SizedBox(height: 32),

          // ── Napi Költségkorlát ───────────────────────────────────
          _buildCostLimitCard(),
          const SizedBox(height: 32),

          // ── AI Modellek ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AI Modellek',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Új modell'),
                onPressed: () => _showModelDialog(null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._models.map(_buildModelRow),

          const SizedBox(height: 32),

          // ── Utolsó GPT hívások ───────────────────────────────────
          const Text('Legutóbbi OpenAI hívások',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (_gptLogs.isEmpty)
            _emptyBox(LucideIcons.cpu, 'Még nincs naplózott GPT hívás.')
          else
            ..._gptLogs.map(_buildGptLogRow),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────── Monthly summary card ─────────────────────

  Widget _buildMonthlySummary(double gptMonth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.dollarSign, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text('Havi összköltség',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\$${gptMonth.toStringAsFixed(4)}',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'OpenAI GPT – ${DateTime.now().month}. hónap',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─────────────────── Stat card ────────────────────────────────

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ─────────────────── Cost limit card ──────────────────────────

  Widget _buildCostLimitCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldAlert, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Napi API Költségkorlát',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ha az összesített GPT-költség eléri ezt a keretet, az API hívások blokkolva lesznek.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Napi limit (USD)',
                    labelStyle: TextStyle(color: AppColors.primary.withValues(alpha: 0.7)),
                    prefixIcon: const Icon(LucideIcons.dollarSign, size: 16, color: Colors.white38),
                    filled: true,
                    fillColor: AppColors.background,
                    enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white12),
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _savingLimit ? null : _saveCostLimit,
                icon: _savingLimit
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.save, size: 14),
                label: const Text('Mentés'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveCostLimit() async {
    final val = double.tryParse(_limitCtrl.text.trim());
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Érvényes pozitív számot adj meg!'),
          backgroundColor: Colors.redAccent));
      return;
    }
    setState(() => _savingLimit = true);
    try {
      await _repo.updateAppSetting(
        'daily_api_cost_limit',
        val.toStringAsFixed(2),
        'Globális napi API költségkorlát USD-ben.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Napi limit elmentve!'), backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hiba: $e'), backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating));
      }
    }
    if (mounted) setState(() => _savingLimit = false);
  }

  // ─────────────────── Model row ────────────────────────────────

  Widget _buildModelRow(AiModel m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: m.isDefault
              ? AppColors.primary.withValues(alpha: 0.5)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.cpu,
              size: 18,
              color: m.isDefault ? AppColors.primary : Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(m.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (m.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Text('Alapértelmezett',
                            style: TextStyle(color: AppColors.primary, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(m.model,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (!m.isDefault)
            IconButton(
              tooltip: 'Beállítás alapértelmezettnek',
              icon: const Icon(LucideIcons.star, size: 16, color: Colors.white38),
              onPressed: () => _setDefault(m.id),
            ),
          IconButton(
            tooltip: 'Szerkesztés',
            icon: const Icon(LucideIcons.pencil, size: 16, color: Colors.white54),
            onPressed: () => _showModelDialog(m),
          ),
          IconButton(
            tooltip: 'Törlés',
            icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
            onPressed: () => _confirmDelete(m),
          ),
        ],
      ),
    );
  }

  Future<void> _setDefault(String id) async {
    try {
      await _repo.setDefaultAiModel(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hiba: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ─────────────────── GPT log row ──────────────────────────────

  Widget _buildGptLogRow(Map<String, dynamic> row) {
    final model   = row['model'] as String? ?? '?';
    final inTok   = row['input_tokens'] as int? ?? 0;
    final outTok  = row['output_tokens'] as int? ?? 0;
    final cost    = (row['cost_usd'] as num?)?.toDouble() ?? 0.0;
    final created = DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.cpu, size: 12, color: Colors.blueAccent.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(model, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Text('↑$inTok ↓$outTok tok',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 12),
          Text('\$${cost.toStringAsFixed(5)}',
              style: TextStyle(
                  color: Colors.greenAccent.withValues(alpha: 0.8), fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          if (created != null)
            Text(
              '${created.hour.toString().padLeft(2, '0')}:'
              '${created.minute.toString().padLeft(2, '0')} '
              '${created.day}.${created.month}.',
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
        ],
      ),
    );
  }

  // ─────────────────── Dialogs ──────────────────────────────────

  void _showModelDialog(AiModel? existing) {
    final nameCtrl  = TextEditingController(text: existing?.name ?? '');
    final modelCtrl = TextEditingController(text: existing?.model ?? '');
    final promptCtrl = TextEditingController(text: existing?.systemPrompt ?? '');
    bool isDefault = existing?.isDefault ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existing == null ? 'Új AI Modell' : 'Modell szerkesztése',
              style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, 'Megnevezés', 'pl. GPT-4o Mini'),
                const SizedBox(height: 12),
                _dialogField(modelCtrl, 'Model azonosító', 'pl. gpt-4o-mini'),
                const SizedBox(height: 12),
                _dialogField(promptCtrl, 'System Prompt (opcionális)', '', maxLines: 3),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: isDefault,
                  title: const Text('Alapértelmezett', style: TextStyle(color: Colors.white)),
                  activeColor: AppColors.primary,
                  onChanged: (v) => setS(() => isDefault = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mégsem', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || modelCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'model': modelCtrl.text.trim(),
                    'system_prompt': promptCtrl.text.trim().isEmpty
                        ? null
                        : promptCtrl.text.trim(),
                    'is_default': isDefault,
                  };
                  if (existing == null) {
                    await _repo.createAiModel(data);
                  } else {
                    await _repo.updateAiModel(existing.id, data);
                  }
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Hiba: $e'), backgroundColor: Colors.redAccent));
                  }
                }
              },
              child: Text(existing == null ? 'Létrehozás' : 'Mentés'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(AiModel m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Törlés megerősítése', style: TextStyle(color: Colors.white)),
        content: Text('Biztosan törlöd a(z) "${m.name}" modellt?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mégsem', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repo.deleteAiModel(m.id);
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Hiba: $e'), backgroundColor: Colors.redAccent));
                }
              }
            },
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
  }

  // ─────────────────── Helpers ──────────────────────────────────

  Widget _dialogField(TextEditingController ctrl, String label, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _emptyBox(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
