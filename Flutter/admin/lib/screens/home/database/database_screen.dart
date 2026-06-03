import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

// ============================================================
// DatabaseScreen – DB table overview via Supabase information_schema
// ============================================================

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  final _db = Supabase.instance.client;

  List<_TableInfo> _tables = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch row counts per table in parallel
      final knownTables = [
        'user_profiles', 'items', 'translations', 'legal_documents',
        'app_settings', 'ai_models', 'gpt_usage_logs', 'app_error_logs',
        'user_push_tokens', 'push_notification_logs',
      ];

      // translations uses 'key' as PK, legal_documents has composite PK — select * for those
      final futures = knownTables.map((t) async {
        try {
          final res = await _db.from(t).select().limit(5000);
          return _TableInfo(name: t, rowCount: (res as List).length, reachable: true);
        } catch (_) {
          return _TableInfo(name: t, rowCount: 0, reachable: false);
        }
      });

      _tables = await Future.wait(futures);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

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
    final reachable = _tables.where((t) => t.reachable).toList();
    final totalRows = reachable.fold<int>(0, (s, t) => s + t.rowCount);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Summary row
          Row(
            children: [
              _summaryCard('Táblák', '${reachable.length}', LucideIcons.table2, Colors.blue),
              const SizedBox(width: 16),
              _summaryCard('Össz. rekord', totalRows.toString(), LucideIcons.database, Colors.purple),
            ],
          ),
          const SizedBox(height: 28),

          const Text('Táblák áttekintése',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),

          ..._tables.map(_buildTableRow),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(_TableInfo t) {
    final icon   = _tableIcon(t.name);
    final color  = t.reachable ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(t.name,
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    fontFamily: 'monospace')),
          ),
          if (t.reachable)
            Text('${t.rowCount} sor',
                style: const TextStyle(color: Colors.white54, fontSize: 12))
          else
            Text('nem elérhető',
                style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  IconData _tableIcon(String name) {
    if (name.contains('user')) return LucideIcons.users;
    if (name.contains('ai_model')) return LucideIcons.cpu;
    if (name.contains('gpt')) return LucideIcons.zap;
    if (name.contains('error')) return LucideIcons.triangleAlert;
    if (name.contains('push') || name.contains('notif')) return LucideIcons.bell;
    if (name.contains('settings')) return LucideIcons.settings;
    if (name.contains('translation')) return LucideIcons.languages;
    if (name.contains('legal')) return LucideIcons.fileText;
    if (name.contains('items')) return LucideIcons.package;
    return LucideIcons.table2;
  }
}

class _TableInfo {
  final String name;
  final int rowCount;
  final bool reachable;
  const _TableInfo({required this.name, required this.rowCount, required this.reachable});
}
