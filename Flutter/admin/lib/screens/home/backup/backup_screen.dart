import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/components/components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/backup_log.dart';
import '../../../repositories/backup_repository.dart';

// ============================================================
// BackupScreen – backup logok + erőforrás grafikonok
// ============================================================

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _repo = BackupRepository();
  List<BackupLog>       _logs      = [];
  List<ResourceSnapshot> _snapshots = [];
  bool _loading  = false;
  bool _triggering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _repo.getBackupLogs(),
        _repo.getResourceSnapshots(),
      ]);
      setState(() {
        _logs      = results[0] as List<BackupLog>;
        _snapshots = results[1] as List<ResourceSnapshot>;
        _loading   = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _triggerManualBackup() async {
    setState(() => _triggering = true);
    try {
      await _repo.triggerManualBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Manuális backup elindítva a háttérben.'),
            backgroundColor: Color(0xFF34D399),
          ),
        );
      }
      await Future.delayed(const Duration(seconds: 3));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Row(children: [
          Icon(LucideIcons.hardDrive, size: 20),
          SizedBox(width: 8),
          Text('Backup & Monitoring'),
        ]),
        actions: [
          if (_triggering)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              icon: const Icon(LucideIcons.play, size: 16),
              label: const Text('Manuális backup', style: TextStyle(fontSize: 12)),
              onPressed: _triggerManualBackup,
            ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(slivers: [
                // ── Resource Monitor kártyák ─────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: _ResourceCards(snapshots: _snapshots),
                  ),
                ),

                // ── Backup log fejléc ────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md, vertical: AppSizes.xs),
                    child: Row(children: [
                      const Icon(LucideIcons.history, size: 16),
                      const SizedBox(width: 6),
                      Text('Backup előzmények',
                          style: AppTypography.label),
                    ]),
                  ),
                ),

                // ── Backup log lista ─────────────────────────────
                if (_logs.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.xl),
                      child: Center(
                        child: Text('Még nincs backup előzmény.',
                            style: TextStyle(color: Colors.white38)),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _BackupLogTile(log: _logs[i]),
                      childCount: _logs.length,
                    ),
                  ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSizes.xl)),
              ]),
            ),
    );
  }
}

// ── Erőforrás monitor kártyák ─────────────────────────────────

class _ResourceCards extends StatelessWidget {
  final List<ResourceSnapshot> snapshots;
  const _ResourceCards({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    final latest = snapshots.isNotEmpty ? snapshots.last : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Szerver állapot (legutóbbi snapshot)',
          style: AppTypography.label),
      const SizedBox(height: AppSizes.sm),
      Row(children: [
        Expanded(child: _MetricCard(
          icon: LucideIcons.cpu,
          label: 'CPU',
          value: latest != null ? '${latest.cpuPercent?.toStringAsFixed(1) ?? '-'}%' : '-',
          percent: latest?.cpuPercent?.toInt(),
          color: _percentColor(latest?.cpuPercent?.toInt() ?? 0),
        )),
        const SizedBox(width: AppSizes.sm),
        Expanded(child: _MetricCard(
          icon: LucideIcons.server,
          label: 'RAM',
          value: latest != null
              ? '${latest.ramPercent.toStringAsFixed(1)}%'
              : '-',
          subtitle: latest != null
              ? '${latest.ramUsedMb ?? '-'}/${latest.ramTotalMb ?? '-'} MB'
              : null,
          percent: latest?.ramPercent.toInt(),
          color: _percentColor(latest?.ramPercent.toInt() ?? 0),
        )),
        const SizedBox(width: AppSizes.sm),
        Expanded(child: _MetricCard(
          icon: LucideIcons.hardDrive,
          label: 'Tárhely',
          value: latest != null
              ? '${latest.diskPercent?.toStringAsFixed(1) ?? '-'}%'
              : '-',
          subtitle: latest != null
              ? '${latest.diskUsedGb?.toStringAsFixed(1) ?? '-'}/'
                '${latest.diskTotalGb?.toStringAsFixed(1) ?? '-'} GB'
              : null,
          percent: latest?.diskPercent?.toInt(),
          color: _percentColor(latest?.diskPercent?.toInt() ?? 0),
        )),
      ]),

      // Mini sparkline (szövegesen, ha nincs chart lib)
      if (snapshots.length > 1) ...[
        const SizedBox(height: AppSizes.md),
        _SimpleSparkline(
          label: 'Disk % – utolsó 24h',
          values: snapshots
              .map((s) => s.diskPercent ?? 0)
              .toList(),
          color: AppColors.accent,
        ),
      ],
    ]);
  }

  Color _percentColor(int pct) {
    if (pct >= 85) return AppColors.error;
    if (pct >= 70) return AppColors.warning;
    return AppColors.success;
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final int? percent;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.bodySmall),
        ]),
        const SizedBox(height: 8),
        Text(value,
            style: AppTypography.titleLarge.copyWith(color: color)),
        if (subtitle != null)
          Text(subtitle!, style: AppTypography.bodySmall),
        if (percent != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (percent! / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ]),
    );
  }
}

class _SimpleSparkline extends StatelessWidget {
  final String label;
  final List<double> values;
  final Color color;

  const _SimpleSparkline({
    required this.label,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTypography.bodySmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: CustomPaint(
            painter: _SparklinePainter(values: values, color: color),
            size: Size.infinite,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('min: ${values.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)}%',
                style: AppTypography.bodySmall.copyWith(fontSize: 10)),
            Text('max: ${values.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}%',
                style: AppTypography.bodySmall.copyWith(fontSize: 10)),
          ],
        ),
      ]),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final range  = (maxVal - minVal).clamp(1.0, double.infinity);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = (1 - (values[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

// ── Backup log sor ────────────────────────────────────────────

class _BackupLogTile extends StatelessWidget {
  final BackupLog log;
  const _BackupLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final statusColor = log.isSuccess
        ? AppColors.success
        : log.isFailed
            ? AppColors.error
            : AppColors.warning;
    final statusIcon = log.isSuccess
        ? LucideIcons.circleCheck
        : log.isFailed
            ? LucideIcons.circleX
            : LucideIcons.loader;
    final statusLabel = log.isSuccess
        ? 'Sikeres'
        : log.isFailed
            ? 'Sikertelen'
            : 'Folyamatban';

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.xs / 2),
      child: AppCard(
        child: Row(children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(log.backupType.toUpperCase(),
                    style: AppTypography.bodySmall.copyWith(color: statusColor)),
                const SizedBox(width: 8),
                Text(statusLabel,
                    style: AppTypography.bodySmall.copyWith(color: statusColor)),
              ]),
              Text(
                _fmt(log.createdAt),
                style: AppTypography.bodySmall,
              ),
              if (log.sizeBytes != null)
                Text(log.sizeFormatted, style: AppTypography.bodySmall),
              if (log.errorMessage != null)
                Text(log.errorMessage!,
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error, fontSize: 11)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(log.triggeredBy,
                style: AppTypography.bodySmall.copyWith(fontSize: 10)),
            if (log.durationSecs != null)
              Text('${log.durationSecs}s', style: AppTypography.bodySmall),
          ]),
        ]),
      ),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2,'0')}.${dt.day.toString().padLeft(2,'0')} '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}
