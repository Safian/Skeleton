import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../repositories/admin_repository.dart';

// ============================================================
// LogsScreen – App error logs + AI usage logs
// ============================================================

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _repo = AdminRepository();
  int _activeSection = 0; // 0 = app logs, 1 = AI logs

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section switcher
            Row(
              children: [
                _tabBtn('App naplók', LucideIcons.triangleAlert, 0),
                const SizedBox(width: 12),
                _tabBtn('AI naplók', LucideIcons.cpu, 1),
              ],
            ),
            const SizedBox(height: 24),

            if (_activeSection == 0)
              _AppLogsSection(repo: _repo)
            else
              _AiLogsSection(repo: _repo),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, IconData icon, int index) {
    final active = _activeSection == index;
    return GestureDetector(
      onTap: () => setState(() => _activeSection = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? AppColors.primary.withValues(alpha: 0.5) : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: active ? AppColors.primary : Colors.white38),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: active ? AppColors.primary : Colors.white54,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── App Error Logs Section ───────────────────

class _AppLogsSection extends StatelessWidget {
  final AdminRepository repo;
  const _AppLogsSection({required this.repo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.fetchAppErrorLogs(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return _LogError(message: '${snap.error}');
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return _LogEmpty(
              icon: LucideIcons.checkCircle2,
              text: 'Nincs app-szintű hiba naplózva — minden rendben! ✅');
        }

        // Count by type
        final typeCounts = <String, int>{};
        for (final r in rows) {
          final t = r['error_type'] as String? ?? 'unknown';
          typeCounts[t] = (typeCounts[t] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in typeCounts.entries)
                  _errorChip(e.key, e.value),
              ],
            ),
            const SizedBox(height: 16),
            for (final row in rows) _AppLogRow(row: row),
          ],
        );
      },
    );
  }

  Widget _errorChip(String type, int count) {
    final color = _errorTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_errorTypeIcon(type), size: 12, color: color),
        const SizedBox(width: 6),
        Text('$type  $count×', style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }
}

class _AppLogRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _AppLogRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final errorType = row['error_type'] as String? ?? 'unknown';
    final message   = row['error_message'] as String? ?? '';
    final app       = row['app'] as String? ?? '?';
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal();
    final ctx       = row['context'] as Map? ?? {};
    final color     = _errorTypeColor(errorType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        leading: Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        title: Text(
          message.length > 120 ? '${message.substring(0, 120)}…' : message,
          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
        ),
        subtitle: Row(children: [
          _appChip(app),
          const SizedBox(width: 8),
          Text(errorType, style: TextStyle(color: color, fontSize: 10)),
          const Spacer(),
          if (createdAt != null)
            Text(
              '${createdAt.hour.toString().padLeft(2, '0')}:'
              '${createdAt.minute.toString().padLeft(2, '0')} '
              '${createdAt.day}.${createdAt.month}.',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
        ]),
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white24,
        children: [
          SelectableText(message,
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.5)),
          if (ctx.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Context: $ctx',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────── AI Logs Section ─────────────────────────

class _AiLogsSection extends StatelessWidget {
  final AdminRepository repo;
  const _AiLogsSection({required this.repo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.fetchGptLogs(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) return _LogError(message: '${snap.error}');

        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return _LogEmpty(icon: LucideIcons.zap, text: 'Még nincs GPT használati napló.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GPT hívások (utolsó ${rows.length})',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
            const SizedBox(height: 12),
            for (final row in rows) _GptLogRow(row: row),
          ],
        );
      },
    );
  }
}

class _GptLogRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _GptLogRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final model   = row['model'] as String? ?? '?';
    final inTok   = row['input_tokens'] as int? ?? 0;
    final outTok  = row['output_tokens'] as int? ?? 0;
    final cost    = (row['cost_usd'] as num?)?.toDouble() ?? 0.0;
    final created = DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        Icon(LucideIcons.cpu, size: 12, color: Colors.blueAccent.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(child: Text(model,
            style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Text('↑$inTok ↓$outTok token',
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
      ]),
    );
  }
}

// ─────────────────── Shared helpers ──────────────────────────

class _LogError extends StatelessWidget {
  final String message;
  const _LogError({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(LucideIcons.triangleAlert, color: Colors.redAccent, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
        ]),
      );
}

class _LogEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _LogEmpty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white24, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ]),
      );
}

Widget _appChip(String app) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(app, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    );

Color _errorTypeColor(String type) {
  switch (type.toLowerCase()) {
    case 'auth_error':   return Colors.orangeAccent;
    case 'network_error': return Colors.blueAccent;
    case 'chat_error':   return Colors.purpleAccent;
    case 'crash':        return Colors.redAccent;
    default:             return Colors.white54;
  }
}

IconData _errorTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'auth_error':    return LucideIcons.lockKeyhole;
    case 'network_error': return LucideIcons.wifi;
    case 'chat_error':    return LucideIcons.messageCircle;
    case 'crash':         return LucideIcons.zap;
    default:              return LucideIcons.triangleAlert;
  }
}
