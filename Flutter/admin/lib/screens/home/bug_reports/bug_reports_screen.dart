import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/bug_report.dart';
import '../../../repositories/bug_report_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/components/components.dart';

// ============================================================
// BugReportsScreen – QA Bug riportok kezelő  [M7]
// ============================================================

class BugReportsScreen extends StatefulWidget {
  const BugReportsScreen({super.key});

  @override
  State<BugReportsScreen> createState() => _BugReportsScreenState();
}

class _BugReportsScreenState extends State<BugReportsScreen> {
  final _repo     = BugReportRepository();
  List<BugReport> _reports  = [];
  bool    _loading          = false;
  String? _error;
  String? _statusFilter;    // null = összes
  String? _priorityFilter;

  static const _statuses   = ['open', 'in_progress', 'resolved', 'wont_fix'];
  static const _priorities = ['critical', 'high', 'medium', 'low'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final reports = await _repo.fetchReports(
        status:   _statusFilter,
        priority: _priorityFilter,
      );
      setState(() { _reports = reports; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _updateStatus(
    BugReport bug,
    String newStatus, {
    String? notes,
  }) async {
    try {
      await _repo.updateStatus(bug.id, newStatus, notes: notes);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Státusz frissítve: $newStatus'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hiba: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Row(children: [
          Icon(Icons.bug_report_rounded, size: 20, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('Bug Riportok'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Szűrők ─────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md, vertical: AppSizes.sm),
            child: Row(children: [
              Expanded(
                child: _DropFilter<String>(
                  value:    _statusFilter,
                  hint:     'Állapot',
                  items:    _statuses,
                  labels:   const {
                    'open':        'Nyitott',
                    'in_progress': 'Folyamatban',
                    'resolved':    'Megoldva',
                    'wont_fix':    'Nem javítandó',
                  },
                  onChanged: (v) {
                    setState(() => _statusFilter = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropFilter<String>(
                  value:    _priorityFilter,
                  hint:     'Prioritás',
                  items:    _priorities,
                  labels:   const {
                    'critical': '🔴 Kritikus',
                    'high':     '🟠 Magas',
                    'medium':   '🟡 Közepes',
                    'low':      '🟢 Alacsony',
                  },
                  onChanged: (v) {
                    setState(() => _priorityFilter = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(LucideIcons.x, size: 14),
                label: const Text('Törlés'),
                onPressed: () {
                  setState(() {
                    _statusFilter   = null;
                    _priorityFilter = null;
                  });
                  _load();
                },
              ),
            ]),
          ),

          // ── Lista / loading / üres ─────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.redAccent)))
                    : _reports.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.checkCircle,
                                    size: 48, color: Colors.green),
                                SizedBox(height: 12),
                                Text('Nincs bug riport 🎉',
                                    style: TextStyle(color: Colors.white38)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(AppSizes.md),
                              itemCount: _reports.length,
                              itemBuilder: (context, index) {
                                return _BugTile(
                                  bug:     _reports[index],
                                  onStatusChange: (status, notes) =>
                                      _updateStatus(
                                          _reports[index], status,
                                          notes: notes),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Bug tile ──────────────────────────────────────────────────

class _BugTile extends StatelessWidget {
  final BugReport bug;
  final Future<void> Function(String status, String? notes) onStatusChange;

  const _BugTile({required this.bug, required this.onStatusChange});

  static const _priorityColors = {
    'critical': Colors.red,
    'high':     Colors.orange,
    'medium':   Colors.yellow,
    'low':      Colors.green,
  };

  static const _statusColors = {
    'open':        Colors.blue,
    'in_progress': Colors.orange,
    'resolved':    Colors.green,
    'wont_fix':    Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final pColor = _priorityColors[bug.priority] ?? Colors.grey;
    final sColor = _statusColors[bug.status] ?? Colors.grey;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: pColor.withValues(alpha: 0.4), width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md, vertical: AppSizes.xs),
        collapsedIconColor: Colors.white38,
        iconColor: Colors.white38,
        title: Row(children: [
          Container(
            width: 4, height: 40,
            decoration: BoxDecoration(
              color: pColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bug.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(children: [
                  AppBadge(label: bug.priority.toUpperCase(), color: pColor),
                  const SizedBox(width: 6),
                  AppBadge(label: bug.statusLabel, color: sColor),
                  const SizedBox(width: 6),
                  Text(
                    bug.routeName ?? '',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ]),
              ],
            ),
          ),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, 0, AppSizes.md, AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leírás
                if (bug.description != null && bug.description!.isNotEmpty) ...[
                  Text(
                    bug.description!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],

                // Eszköz info
                _InfoRow(icon: LucideIcons.smartphone,
                    label: '${bug.deviceModel} · ${bug.osName} ${bug.osVersion}'),
                _InfoRow(icon: LucideIcons.code,
                    label: 'v${bug.appVersion}'),
                _InfoRow(icon: LucideIcons.calendar,
                    label: bug.createdAt.toLocal().toString().substring(0, 16)),

                if (bug.screenshotUrl != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _openScreenshot(context, bug.screenshotUrl!),
                    child: const Row(children: [
                      Icon(LucideIcons.image, size: 14, color: Colors.blueAccent),
                      SizedBox(width: 6),
                      Text('Screenshot megtekintése',
                          style: TextStyle(
                              color: Colors.blueAccent, fontSize: 12,
                              decoration: TextDecoration.underline)),
                    ]),
                  ),
                ],

                // Log preview
                if (bug.logs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    collapsedIconColor: Colors.white38,
                    title: const Text('Logok megtekintése',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    children: [
                      Container(
                        height: 120,
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            bug.logs.join('\n'),
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const Divider(height: 20),

                // Státusz gombok
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in [
                      ('in_progress', 'Folyamatba', Colors.orange),
                      ('resolved',    'Megoldva',   Colors.green),
                      ('wont_fix',    'Nem javítandó', Colors.grey),
                      ('open',        'Visszanyitás',  Colors.blue),
                    ])
                      if (bug.status != status.$1)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: status.$3,
                            side: BorderSide(color: status.$3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => onStatusChange(status.$1, null),
                          child: Text(status.$2,
                              style: const TextStyle(fontSize: 12)),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openScreenshot(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        contentPadding: EdgeInsets.zero,
        content: Image.network(url, fit: BoxFit.contain),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

// ── Dropdown szűrő ────────────────────────────────────────────

class _DropFilter<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final Map<T, String>? labels;
  final ValueChanged<T?> onChanged;

  const _DropFilter({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value:        value,
          hint:         Text(hint,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          isExpanded:   true,
          isDense:      true,
          dropdownColor: AppColors.surface,
          items: [
            DropdownMenuItem<T>(
                value: null,
                child: Text(hint,
                    style: const TextStyle(color: Colors.white54, fontSize: 13))),
            ...items.map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labels?[item] ?? item.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
