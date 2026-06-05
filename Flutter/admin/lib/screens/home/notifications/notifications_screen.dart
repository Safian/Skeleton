import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../repositories/admin_repository.dart';

// ============================================================
// NotificationsScreen – push notification sender + log
// ============================================================

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = AdminRepository();
  final _db   = Supabase.instance.client;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();

  String _targetGroup = 'all'; // 'all', 'user'
  String? _targetUserId;
  bool _sending = false;

  List<Map<String, dynamic>> _logs = [];
  bool _logsLoading = true;
  int _tokenCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _logsLoading = true);
    try {
      final results = await Future.wait([
        _repo.fetchPushLogs(),
        _repo.fetchPushTokenCount(),
      ]);
      _logs       = results[0] as List<Map<String, dynamic>>;
      _tokenCount = results[1] as int;
    } catch (_) {}
    if (mounted) setState(() => _logsLoading = false);
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Töltsd ki a cím és szöveg mezőket!'),
          backgroundColor: Colors.orangeAccent));
      return;
    }
    setState(() => _sending = true);
    try {
      final response = await _db.functions.invoke(
        'send-push',
        body: {
          'title':          title,
          'body':           body,
          'target_group':   _targetGroup,
          if (_targetUserId != null) 'target_user_id': _targetUserId,
        },
      );
      if (response.status == 200) {
        _titleCtrl.clear();
        _bodyCtrl.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Push üzenet sikeresen elküldve!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating));
        }
        _loadLogs();
      } else {
        throw response.data?['error'] ?? 'Ismeretlen hiba';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hiba: $e'), backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

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

            // ── Token count summary ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.smartphone, color: AppColors.primary, size: 24),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_tokenCount regisztrált eszköz',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      const SizedBox(height: 4),
                      Text('Push token aktív adatbázisban',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Send form ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Új push üzenet küldése',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),

                  // Target group
                  DropdownButtonFormField<String>(
                    value: _targetGroup,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Célcsoport',
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'all',
                          child: Text('Mindenki')),
                      DropdownMenuItem(
                          value: 'subscribers',
                          child: Text('Csak előfizetők')),
                      DropdownMenuItem(
                          value: 'non_subscribers',
                          child: Text('Nem előfizetők')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _targetGroup = v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Title
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Értesítés cím',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'pl. Új funkció!',
                      hintStyle: const TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Body
                  TextField(
                    controller: _bodyCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Értesítés szövege',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'pl. Fedezd fel az újdonságokat...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(LucideIcons.send, size: 18),
                      label: Text(
                        _sending ? 'Küldés folyamatban...' : 'Push üzenet kiküldése',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Send history ─────────────────────────────────────
            const Text('Korábbi értesítések',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),

            if (_logsLoading)
              const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ))
            else if (_logs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(children: [
                  Icon(LucideIcons.bell, color: Colors.white24, size: 20),
                  SizedBox(width: 12),
                  Text('Még nem küldtél push értesítést.',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ]),
              )
            else
              ..._logs.map(_buildLogRow),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLogRow(Map<String, dynamic> row) {
    final title   = row['title'] as String? ?? '';
    final body    = row['body'] as String? ?? '';
    final target  = row['target_group'] as String? ?? '';
    final status  = row['status'] as String? ?? '';
    final count   = row['tokens_count'] as int? ?? 0;
    final created = DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal();
    final ok      = status == 'success';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: ok
                ? Colors.greenAccent.withValues(alpha: 0.2)
                : Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
                size: 14,
                color: ok ? Colors.greenAccent : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13))),
              if (created != null)
                Text(
                  '${created.day}.${created.month}. '
                  '${created.hour.toString().padLeft(2, '0')}:'
                  '${created.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(
            children: [
              _chip(target, Colors.blueAccent),
              const SizedBox(width: 8),
              _chip('$count eszköz', Colors.white38),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10)),
      );
}
