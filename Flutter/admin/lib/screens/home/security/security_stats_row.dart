import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/security_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';

class SecurityStatsRow extends StatelessWidget {
  const SecurityStatsRow({
    super.key,
    required this.stats,
    this.isLoading = false,
  });

  final SecurityStats? stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null || isLoading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        final cards = [
          _StatCard(
            icon: LucideIcons.shieldAlert,
            color: s.unresolvedEvents > 0 ? Colors.red : Colors.grey,
            label: 'Nyitott riasztás',
            value: s.unresolvedEvents.toString(),
          ),
          _StatCard(
            icon: LucideIcons.ban,
            color: s.activeBans > 0 ? Colors.orange : Colors.grey,
            label: 'Aktív tiltás',
            value: s.activeBans.toString(),
          ),
          _StatCard(
            icon: LucideIcons.activity,
            color: Colors.blue,
            label: 'Ma összesen',
            value: s.eventsToday.toString(),
          ),
          _StatCard(
            icon: LucideIcons.key,
            color: s.sshLoginCount > 0 ? Colors.amber : Colors.grey,
            label: 'SSH belépés (24h)',
            value: s.sshLoginCount.toString(),
          ),
          if (s.topAttackerIp != null)
            _StatCard(
              icon: LucideIcons.skull,
              color: Colors.red.shade900,
              label: 'Legtöbb támadó',
              value: s.topAttackerIp!,
              small: true,
            ),
        ];

        if (isWide) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSizes.sm),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: AppSizes.sm,
          mainAxisSpacing: AppSizes.sm,
          childAspectRatio: 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.small = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: small ? 13 : 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
