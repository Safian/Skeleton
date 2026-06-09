import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/security_log.dart';

class SecurityLogTile extends StatelessWidget {
  const SecurityLogTile({
    super.key,
    required this.log,
    this.onResolve,
    this.onUnban,
  });

  final SecurityLog log;
  final VoidCallback? onResolve;
  final VoidCallback? onUnban;

  static Color _eventColor(SecurityEventType t) => switch (t) {
        SecurityEventType.bruteForce         => Colors.red,
        SecurityEventType.successfulSshLogin => Colors.amber,
        SecurityEventType.rateLimitExceeded  => Colors.orange,
        SecurityEventType.portScan           => Colors.purple,
        SecurityEventType.banned             => Colors.red.shade900,
        SecurityEventType.unbanned           => Colors.green,
        SecurityEventType.unknown            => Colors.grey,
      };

  static IconData _eventIcon(SecurityEventType t) => switch (t) {
        SecurityEventType.bruteForce         => LucideIcons.shieldAlert,
        SecurityEventType.successfulSshLogin => LucideIcons.key,
        SecurityEventType.rateLimitExceeded  => LucideIcons.gauge,
        SecurityEventType.portScan           => LucideIcons.scanLine,
        SecurityEventType.banned             => LucideIcons.ban,
        SecurityEventType.unbanned           => LucideIcons.shieldCheck,
        SecurityEventType.unknown            => LucideIcons.circleHelp,
      };

  @override
  Widget build(BuildContext context) {
    final color    = _eventColor(log.eventType);
    final icon     = _eventIcon(log.eventType);
    final resolved = log.isResolved;

    return Opacity(
      opacity: resolved ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.xs / 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: resolved ? Colors.grey : color, width: 3),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.xs,
          ),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  log.eventType.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              // Forrás badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.source,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              if (log.ipAddress != null)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: log.ipAddress!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('IP vágólapra másolva'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.network, size: 11, color: color.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        log.ipAddress!,
                        style: TextStyle(
                          fontSize: 12,
                          color: color.withValues(alpha: 0.9),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              if (log.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    log.description!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(log.timestamp),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          trailing: resolved
              ? const Icon(LucideIcons.checkCircle, size: 16, color: Colors.green)
              : PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                  color: AppColors.surface,
                  itemBuilder: (_) => [
                    if (onResolve != null)
                      const PopupMenuItem(
                        value: 'resolve',
                        child: Row(children: [
                          Icon(LucideIcons.checkCircle, size: 14),
                          SizedBox(width: 8),
                          Text('Lezárás'),
                        ]),
                      ),
                    if (onUnban != null)
                      const PopupMenuItem(
                        value: 'unban',
                        child: Row(children: [
                          Icon(LucideIcons.shieldCheck, size: 14, color: Colors.green),
                          SizedBox(width: 8),
                          Text('IP Feloldása', style: TextStyle(color: Colors.green)),
                        ]),
                      ),
                  ],
                  onSelected: (v) {
                    if (v == 'resolve') onResolve?.call();
                    if (v == 'unban') onUnban?.call();
                  },
                ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_p(local.month)}-${_p(local.day)} '
        '${_p(local.hour)}:${_p(local.minute)}:${_p(local.second)}';
  }

  String _p(int v) => v.toString().padLeft(2, '0');
}
