import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../blocs/app_config/app_config_cubit.dart';
import '../../../blocs/app_config/app_config_state.dart';
import '../../../models/app_config.dart';
import '../../../repositories/app_config_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/components/components.dart';

// ============================================================
// ConfigScreen – Feature Flags + Karbantartás mód vezérlő  [M5]
// ============================================================

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AppConfigCubit(repository: AppConfigRepository())..load(),
      child: const _ConfigView(),
    );
  }
}

class _ConfigView extends StatelessWidget {
  const _ConfigView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppConfigCubit, AppConfigState>(
      listenWhen: (p, c) => c.error != null && c.error != p.error,
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.error!),
            backgroundColor: Colors.red.shade700,
          ));
        }
      },
      builder: (context, state) {
        final cubit = context.read<AppConfigCubit>();
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: const Row(children: [
              Icon(LucideIcons.sliders, size: 20),
              SizedBox(width: 8),
              Text('App Konfig & Feature Flagek'),
            ]),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: cubit.load,
                tooltip: 'Frissítés',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: state.isLoading && state.entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: cubit.load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSizes.md),
                    children: [
                      // ── Karbantartás mód card ─────────────
                      _MaintenanceCard(state: state, cubit: cubit),
                      const SizedBox(height: AppSizes.lg),

                      // ── Verzió beállítások ────────────────
                      _VersionCard(state: state, cubit: cubit),
                      const SizedBox(height: AppSizes.lg),

                      // ── Feature Flagek ────────────────────
                      _FlagsCard(
                        flags: state.featureFlags,
                        cubit: cubit,
                        savingKey: state.savingKey,
                      ),
                      const SizedBox(height: AppSizes.lg),

                      // ── Egyéb beállítások ────────────────
                      if (state.otherEntries.isNotEmpty) ...[
                        _OtherEntriesCard(
                          entries: state.otherEntries,
                          cubit:   cubit,
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

// ── Karbantartás mód card ─────────────────────────────────────

class _MaintenanceCard extends StatefulWidget {
  final AppConfigState state;
  final AppConfigCubit cubit;

  const _MaintenanceCard({required this.state, required this.cubit});

  @override
  State<_MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends State<_MaintenanceCard> {
  late TextEditingController _titleCtrl;
  late TextEditingController _msgCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.state.maintenanceTitle);
    _msgCtrl   = TextEditingController(text: widget.state.maintenanceMessage);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOn      = widget.state.maintenanceMode;
    final isSaving  = widget.state.savingKey == 'maintenance_mode';

    return GlassCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fejléc + toggle
          Row(children: [
            Icon(
              LucideIcons.construction,
              color: isOn ? AppColors.warning : AppColors.onSurface,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Karbantartás Mód',
                  style: AppTypography.titleMedium),
            ),
            if (isSaving)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(
                value: isOn,
                activeColor: AppColors.warning,
                onChanged: (v) => _saveMaintenanceMode(v),
              ),
          ]),

          if (isOn) ...[
            const SizedBox(height: 4),
            Text(
              'AZ APP JELENLEG KARBANTARTÁS ALATT VAN',
              style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
            ),
          ],

          const Divider(height: 24),

          // Cím
          const Text('Karbantartás cím', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecor('Cím szövege'),
          ),
          const SizedBox(height: 12),

          // Üzenet
          const Text('Üzenet', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _msgCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecor('Karbantartás üzenete (HTML is OK)'),
          ),
          const SizedBox(height: 12),

          // Mentés gomb
          AppButton(
            label: 'Szövegek mentése',
            icon: LucideIcons.save,
            variant: AppButtonVariant.secondary,
            onTap: () => _saveMaintenanceMode(isOn),
          ),
        ],
      ),
    );
  }

  void _saveMaintenanceMode(bool enabled) {
    widget.cubit.setMaintenanceMode(
      enabled,
      title:   _titleCtrl.text.trim(),
      message: _msgCtrl.text.trim(),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText:     hint,
      hintStyle:    const TextStyle(color: Colors.white24, fontSize: 13),
      filled:       true,
      fillColor:    AppColors.surfaceVariant,
      border:       OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

// ── Verzió card ───────────────────────────────────────────────

class _VersionCard extends StatelessWidget {
  final AppConfigState state;
  final AppConfigCubit cubit;

  const _VersionCard({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.smartphone, size: 18),
            const SizedBox(width: 8),
            Text('Verzió Beállítások', style: AppTypography.titleMedium),
          ]),
          const Divider(height: 20),
          ...state.versionEntries.map((entry) => _EntryRow(
            entry: entry,
            cubit: cubit,
            savingKey: state.savingKey,
          )),
        ],
      ),
    );
  }
}

// ── Feature Flagek card ───────────────────────────────────────

class _FlagsCard extends StatelessWidget {
  final List<AppConfigEntry> flags;
  final AppConfigCubit cubit;
  final String? savingKey;

  const _FlagsCard({
    required this.flags,
    required this.cubit,
    this.savingKey,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.toggleLeft, size: 18),
            const SizedBox(width: 8),
            Text('Feature Flagek', style: AppTypography.titleMedium),
          ]),
          const Divider(height: 20),
          ...flags.map((entry) => _FlagRow(
            entry:     entry,
            cubit:     cubit,
            isSaving:  savingKey == entry.key,
          )),
        ],
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  final AppConfigEntry entry;
  final AppConfigCubit cubit;
  final bool isSaving;

  const _FlagRow({
    required this.entry,
    required this.cubit,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _humanize(entry.key),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              if (entry.description.isNotEmpty)
                Text(
                  entry.description,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),
        ),
        isSaving
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                value:    entry.boolValue,
                onChanged: (v) => cubit.setFlag(entry.key, v),
              ),
      ]),
    );
  }

  String _humanize(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceFirst('feature ', '')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

// ── Egyedi bejegyzés sor ──────────────────────────────────────

class _EntryRow extends StatefulWidget {
  final AppConfigEntry entry;
  final AppConfigCubit cubit;
  final String? savingKey;

  const _EntryRow({
    required this.entry,
    required this.cubit,
    this.savingKey,
  });

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.entry.value);
  }

  @override
  void didUpdateWidget(_EntryRow old) {
    super.didUpdateWidget(old);
    if (!_editing) _ctrl.text = widget.entry.value;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = widget.savingKey == widget.entry.key;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.entry.key,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 11,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onTap: () => setState(() => _editing = true),
                decoration: InputDecoration(
                  isDense:    true,
                  filled:     true,
                  fillColor:  AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:   const BorderSide(color: Colors.white12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        isSaving
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(LucideIcons.check, size: 16,
                    color: Colors.greenAccent),
                tooltip: 'Mentés',
                onPressed: () {
                  setState(() => _editing = false);
                  widget.cubit.updateEntry(
                    widget.entry.key,
                    _ctrl.text.trim(),
                  );
                },
              ),
      ]),
    );
  }
}

// ── Egyéb bejegyzések card ────────────────────────────────────

class _OtherEntriesCard extends StatelessWidget {
  final List<AppConfigEntry> entries;
  final AppConfigCubit cubit;

  const _OtherEntriesCard({required this.entries, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.settings, size: 18),
            const SizedBox(width: 8),
            Text('Egyéb beállítások', style: AppTypography.titleMedium),
          ]),
          const Divider(height: 20),
          ...entries.map((entry) => _EntryRow(entry: entry, cubit: cubit)),
        ],
      ),
    );
  }
}
