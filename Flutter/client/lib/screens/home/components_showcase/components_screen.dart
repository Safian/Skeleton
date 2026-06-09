import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';


// ============================================================
// ComponentsScreen – Tab 3 – összes UI komponens bemutatója
// ============================================================

class ComponentsScreen extends StatefulWidget {
  const ComponentsScreen({super.key});

  @override
  State<ComponentsScreen> createState() => _ComponentsScreenState();
}

class _ComponentsScreenState extends State<ComponentsScreen> {
  bool _switchValue = true;
  double _sliderValue = 0.4;
  bool _checkValue = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('UI Komponensek')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Buttons ─────────────────────────────────────────
          _Section(
            title: 'Gombok',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: 'Primary Button',
                  icon: LucideIcons.zap,
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Secondary Button',
                  variant: AppButtonVariant.secondary,
                  icon: LucideIcons.star,
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Danger Button',
                  variant: AppButtonVariant.danger,
                  icon: LucideIcons.trash2,
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Ghost Button',
                  variant: AppButtonVariant.ghost,
                  icon: LucideIcons.externalLink,
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Loading...',
                  isLoading: true,
                  onTap: null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: AppButton(
                      label: 'Kis gomb',
                      onTap: () {},
                      fullWidth: false,
                    )),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: AppButton(
                      label: 'Letiltva',
                      onTap: null,
                    )),
                  ],
                ),
              ],
            ),
          ),

          // ── Badges ──────────────────────────────────────────
          _Section(
            title: 'Badge-ek',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppBadge(
                  label: 'Primary',
                  variant: AppBadgeVariant.primary,
                  icon: LucideIcons.star,
                ),
                AppBadge(
                  label: 'Sikeres',
                  variant: AppBadgeVariant.success,
                  icon: LucideIcons.check,
                ),
                AppBadge(
                  label: 'Figyelmeztetés',
                  variant: AppBadgeVariant.warning,
                  icon: LucideIcons.triangleAlert,
                ),
                AppBadge(
                  label: 'Hiba',
                  variant: AppBadgeVariant.error,
                  icon: LucideIcons.x,
                ),
                AppBadge(
                  label: 'Semleges',
                  variant: AppBadgeVariant.neutral,
                ),
              ],
            ),
          ),

          // ── Avatars ─────────────────────────────────────────
          _Section(
            title: 'Avatarok',
            child: Row(
              children: [
                AppAvatar(name: 'Kovács Péter', size: 56),
                const SizedBox(width: AppSpacing.md),
                AppAvatar(name: 'A B', size: 48,
                    color: AppColors.secondary.withValues(alpha: 0.25)),
                const SizedBox(width: AppSpacing.md),
                AppAvatar(
                  fallbackIcon: LucideIcons.user,
                  size: 44,
                  color: AppColors.surfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                const AppAvatar(name: 'X', size: 36),
                const SizedBox(width: AppSpacing.md),
                const AppAvatar(name: 'Y', size: 28),
              ],
            ),
          ),

          // ── Text Fields ─────────────────────────────────────
          _Section(
            title: 'Szövegmezők',
            child: Column(
              children: [
                AppTextField(
                  label: 'Alapértelmezett mező',
                  hint: 'Írj be valamit...',
                  prefixIcon: LucideIcons.type,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Email mező',
                  hint: 'pelda@email.com',
                  prefixIcon: LucideIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Hibás mező',
                  hint: 'Hibás érték...',
                  prefixIcon: LucideIcons.alertCircle,
                  errorText: 'Ez a mező kötelező!',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Többsoros mező',
                  hint: 'Hosszabb szöveg...',
                  maxLines: 3,
                ),
              ],
            ),
          ),

          // ── Cards ───────────────────────────────────────────
          _Section(
            title: 'Kártyák',
            child: Column(
              children: [
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alap kártya', style: AppTypography.titleSmall),
                        const SizedBox(height: 4),
                        Text('Ez egy sima AppCard komponens.',
                            style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Glass kártya', style: AppTypography.titleSmall),
                        const SizedBox(height: 4),
                        Text('Semi-transparent glass effekt.',
                            style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(LucideIcons.touchpad,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Kattintható kártya',
                            style: AppTypography.titleSmall),
                        const Spacer(),
                        Icon(LucideIcons.chevronRight,
                            size: 16,
                            color: AppColors.onSurface.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── List Tiles ──────────────────────────────────────
          _Section(
            title: 'Lista elemek',
            child: AppCard(
              child: Column(
                children: [
                  AppListTile(
                    title: 'Egyszerű sor',
                    subtitle: 'Rövid leírás itt',
                    leading: AppAvatar(name: 'A', size: 36),
                    onTap: () {},
                  ),
                  Divider(color: AppColors.divider, height: 1),
                  AppListTile(
                    title: 'Badge-es sor',
                    subtitle: 'Státusszal',
                    leading: const Icon(LucideIcons.bell, size: 20),
                    badgeLabel: 'Új',
                    badgeVariant: AppBadgeVariant.primary,
                    onTap: () {},
                  ),
                  Divider(color: AppColors.divider, height: 1),
                  AppListTile(
                    title: 'Trailing widget',
                    showChevron: false,
                    trailing: Switch(
                      value: _switchValue,
                      onChanged: (v) => setState(() => _switchValue = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Form Controls ────────────────────────────────────
          _Section(
            title: 'Form vezérlők',
            child: AppCard(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Text('Switch', style: AppTypography.label),
                        const Spacer(),
                        Switch(
                          value: _switchValue,
                          onChanged: (v) =>
                              setState(() => _switchValue = v),
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppColors.divider, height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Text('Checkbox', style: AppTypography.label),
                        const Spacer(),
                        Checkbox(
                          value: _checkValue,
                          onChanged: (v) =>
                              setState(() => _checkValue = v ?? false),
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppColors.divider, height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Slider', style: AppTypography.label),
                            const Spacer(),
                            Text(
                              '${(_sliderValue * 100).round()}%',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                        Slider(
                          value: _sliderValue,
                          onChanged: (v) =>
                              setState(() => _sliderValue = v),
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.divider,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Typography ───────────────────────────────────────
          _Section(
            title: 'Tipográfia',
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Display Large', style: AppTypography.displayLarge),
                    Text('Display Medium', style: AppTypography.displayMedium),
                    Text('Title Large', style: AppTypography.titleLarge),
                    Text('Title Medium', style: AppTypography.titleMedium),
                    Text('Title Small', style: AppTypography.titleSmall),
                    Text('Body Large', style: AppTypography.bodyLarge),
                    Text('Body Medium', style: AppTypography.bodyMedium),
                    Text('Body Small', style: AppTypography.bodySmall),
                    Text('EYEBROW / LABEL', style: AppTypography.eyebrow),
                    Text('Button Text', style: AppTypography.button
                        .copyWith(color: AppColors.primary)),
                    Text('monospace code', style: AppTypography.mono),
                  ],
                ),
              ),
            ),
          ),

          // ── Colors ──────────────────────────────────────────
          _Section(
            title: 'Színpaletta',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _ColorChip('Primary', AppColors.primary),
                _ColorChip('Variant', AppColors.primaryVariant),
                _ColorChip('Secondary', AppColors.secondary),
                _ColorChip('Accent', AppColors.accent),
                _ColorChip('Success', AppColors.success),
                _ColorChip('Warning', AppColors.warning),
                _ColorChip('Error', AppColors.error),
                _ColorChip('Surface', AppColors.surface),
                _ColorChip('SurfaceVar', AppColors.surfaceVariant),
                _ColorChip('Background', AppColors.background),
              ],
            ),
          ),

          // ── Empty / Loading states ────────────────────────────
          _Section(
            title: 'Állapotok',
            child: Column(
              children: [
                AppCard(
                  child: SizedBox(
                    height: 120,
                    child: AppEmptyState(
                      icon: LucideIcons.inbox,
                      title: 'Üres állapot',
                      subtitle: 'Nincsenek elemek megjelenítendő',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: SizedBox(
                    height: 80,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ── Helper widgetek ─────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        child,
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ColorChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: Text(label,
            style: AppTypography.eyebrow.copyWith(fontSize: 9),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
