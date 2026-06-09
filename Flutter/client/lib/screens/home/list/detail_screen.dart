import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/items/items_cubit.dart';
import '../../../models/item.dart';

// ============================================================
// DetailScreen – lista elem részletes nézet
// ============================================================

class DetailScreen extends StatelessWidget {
  final Item item;

  const DetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Részletek'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.ellipsis),
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero fejléc
            AppCard(
              child: Row(
                children: [
                  AppAvatar(name: item.title, size: 56),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: AppTypography.titleMedium),
                        if (item.category != null) ...[
                          const SizedBox(height: 4),
                          AppBadge(
                            label: item.category!,
                            variant: AppBadgeVariant.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppBadge(
                    label: item.isActive ? 'Aktív' : 'Inaktív',
                    variant: item.isActive
                        ? AppBadgeVariant.success
                        : AppBadgeVariant.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Leírás
            if (item.description != null) ...[
              const AppSectionHeader(title: 'Leírás'),
              AppCard(
                child: Text(item.description!,
                    style: AppTypography.bodyMedium.copyWith(height: 1.6)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Meta adatok
            const AppSectionHeader(title: 'Részletek'),
            AppCard(
              child: Column(
                children: [
                  _DetailRow(
                    icon: LucideIcons.fingerprint,
                    label: 'Azonosító',
                    value: item.id,
                  ),
                  Divider(color: AppColors.divider, height: 1),
                  _DetailRow(
                    icon: LucideIcons.calendar,
                    label: 'Létrehozva',
                    value: _formatDate(item.createdAt),
                  ),
                  if (item.category != null) ...[
                    Divider(color: AppColors.divider, height: 1),
                    _DetailRow(
                      icon: LucideIcons.tag,
                      label: 'Kategória',
                      value: item.category!,
                    ),
                  ],
                  Divider(color: AppColors.divider, height: 1),
                  _DetailRow(
                    icon: LucideIcons.activity,
                    label: 'Státusz',
                    value: item.isActive ? 'Aktív' : 'Inaktív',
                    valueColor: item.isActive
                        ? AppColors.success
                        : AppColors.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Gombok
            AppButton(
              label: 'Szerkesztés',
              icon: LucideIcons.pencil,
              onTap: () => _showEditSheet(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Törlés',
              variant: AppButtonVariant.danger,
              icon: LucideIcons.trash2,
              onTap: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  void _showEditSheet(BuildContext context) {
    final titleCtrl = TextEditingController(text: item.title);
    final descCtrl  = TextEditingController(text: item.description ?? '');
    final cubit     = context.read<ItemsCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg, right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Szerkesztés', style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Cím',
                labelStyle: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.6)),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Leírás',
                labelStyle: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.6)),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Mentés',
              icon: LucideIcons.save,
              onTap: () {
                cubit.updateItem(
                  item.id,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsListTile(
              icon: LucideIcons.pencil,
              title: 'Szerkesztés',
              onTap: () => Navigator.pop(context),
            ),
            SettingsListTile(
              icon: LucideIcons.share2,
              title: 'Megosztás',
              onTap: () => Navigator.pop(context),
            ),
            SettingsListTile(
              icon: LucideIcons.trash2,
              title: 'Törlés',
              iconColor: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Törlés megerősítése'),
        content: const Text('Biztosan törölni szeretnéd ezt az elemet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégsem'),
          ),
          TextButton(
            onPressed: () {
              context.read<ItemsCubit>().deleteItem(item.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Törlés',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: AppColors.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: AppTypography.bodySmall),
          ),
          Text(value,
              style: AppTypography.label.copyWith(
                  color: valueColor ?? AppColors.onSurface)),
        ],
      ),
    );
  }
}
