import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/security_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';

class BannedIpsSheet extends StatelessWidget {
  const BannedIpsSheet({
    super.key,
    required this.bannedIps,
    required this.onUnban,
    this.unbanning,
  });

  final List<BannedIp> bannedIps;
  final void Function(String ip, String? jail) onUnban;
  final String? unbanning;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (context, controller) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.ban, size: 20, color: Colors.orange),
                const SizedBox(width: 10),
                Text(
                  'Tiltott IP-k (${bannedIps.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista
          Expanded(
            child: bannedIps.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.shieldCheck, size: 40, color: Colors.green),
                        SizedBox(height: 8),
                        Text('Nincs aktív tiltás', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: bannedIps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, i) {
                      final ban       = bannedIps[i];
                      final isUnbanning = unbanning == ban.ipAddress;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.network,
                              size: 16,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ban.ipAddress,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (ban.jail != null)
                                    Text(
                                      'Jail: ${ban.jail}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  if (ban.reason != null)
                                    Text(
                                      ban.reason!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    _formatDate(ban.bannedAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Unban gomb
                            isUnbanning
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.green,
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      LucideIcons.shieldCheck,
                                      size: 18,
                                      color: Colors.green,
                                    ),
                                    tooltip: 'IP Feloldása',
                                    onPressed: () =>
                                        onUnban(ban.ipAddress, ban.jail),
                                  ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${_p(l.month)}-${_p(l.day)} ${_p(l.hour)}:${_p(l.minute)}';
  }

  String _p(int v) => v.toString().padLeft(2, '0');
}
