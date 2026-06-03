import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../blocs/security/security_cubit.dart';
import '../../../models/security_log.dart';
import '../../../repositories/security_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/components/components.dart';
import 'security_log_tile.dart';
import 'security_stats_row.dart';
import 'banned_ips_sheet.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SecurityCubit(repository: SecurityRepository())..load(),
      child: const _SecurityView(),
    );
  }
}

class _SecurityView extends StatefulWidget {
  const _SecurityView();

  @override
  State<_SecurityView> createState() => _SecurityViewState();
}

class _SecurityViewState extends State<_SecurityView> {
  final _ipController = TextEditingController();
  String? _selectedEventType;
  String? _selectedSource;
  bool? _resolvedFilter;

  static const _eventTypes = [
    'brute_force',
    'successful_ssh_login',
    'rate_limit_exceeded',
    'port_scan',
    'banned',
    'unbanned',
  ];

  static const _sources = [
    'fail2ban',
    'ssh_monitor',
    'auth_service',
    'admin_panel',
  ];

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _applyFilters(SecurityCubit cubit) {
    cubit.setIpFilter(_ipController.text.trim());
    cubit.setEventTypeFilter(_selectedEventType);
    cubit.setSourceFilter(_selectedSource);
    cubit.setResolvedFilter(_resolvedFilter);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return BlocConsumer<SecurityCubit, SecurityState>(
      listenWhen: (prev, curr) => curr.error != null && curr.error != prev.error,
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<SecurityCubit>();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: const Row(
              children: [
                Icon(LucideIcons.shieldAlert, size: 20),
                SizedBox(width: 8),
                Text('Biztonság & Riasztások'),
              ],
            ),
            actions: [
              // Tiltott IP-k gomb
              TextButton.icon(
                icon: const Icon(LucideIcons.ban, size: 16),
                label: Text(
                  'Tiltott IP-k (${state.stats?.activeBans ?? 0})',
                  style: const TextStyle(fontSize: 13),
                ),
                onPressed: () => _showBannedIpsSheet(context, cubit, state),
              ),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                tooltip: 'Frissítés',
                onPressed: cubit.load,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: cubit.load,
            child: CustomScrollView(
              slivers: [
                // ── Stats ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: SecurityStatsRow(
                      stats: state.stats,
                      isLoading: state.status == SecurityStatus.loading,
                    ),
                  ),
                ),

                // ── Szűrők ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: AppSizes.xs,
                    ),
                    child: _FilterBar(
                      ipController:        _ipController,
                      selectedEventType:   _selectedEventType,
                      selectedSource:      _selectedSource,
                      resolvedFilter:      _resolvedFilter,
                      eventTypes:          _eventTypes,
                      sources:             _sources,
                      isWide:              isWide,
                      onEventTypeChanged:  (v) {
                        setState(() => _selectedEventType = v);
                        _applyFilters(cubit);
                      },
                      onSourceChanged:     (v) {
                        setState(() => _selectedSource = v);
                        _applyFilters(cubit);
                      },
                      onResolvedChanged:   (v) {
                        setState(() => _resolvedFilter = v);
                        _applyFilters(cubit);
                      },
                      onIpSearch:          () => _applyFilters(cubit),
                      onClearFilters:      () {
                        setState(() {
                          _selectedEventType = null;
                          _selectedSource    = null;
                          _resolvedFilter    = null;
                          _ipController.clear();
                        });
                        cubit.clearFilters();
                      },
                    ),
                  ),
                ),

                // ── Log lista ────────────────────────────────
                if (state.status == SecurityStatus.loading && state.logs.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.logs.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.shieldCheck, size: 48, color: Colors.green),
                          SizedBox(height: 12),
                          Text('Nincs riasztás', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final log = state.logs[index];
                        return SecurityLogTile(
                          log: log,
                          onResolve: log.isResolved
                              ? null
                              : () => cubit.resolveLog(log.id),
                          onUnban: log.ipAddress != null
                              ? () => _confirmUnban(context, cubit, log.ipAddress!)
                              : null,
                        );
                      },
                      childCount: state.logs.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xl)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBannedIpsSheet(
    BuildContext context,
    SecurityCubit cubit,
    SecurityState state,
  ) {
    showModalBottomSheet(
      context:        context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BannedIpsSheet(
        bannedIps: state.bannedIps,
        unbanning: state.unbanning,
        onUnban:   (ip, jail) => _confirmUnban(context, cubit, ip, jail: jail),
      ),
    );
  }

  Future<void> _confirmUnban(
    BuildContext context,
    SecurityCubit cubit,
    String ip, {
    String? jail,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('IP Feloldása'),
        content: Text(
          'Biztosan feloldod ezt az IP-t?\n\n$ip${jail != null ? '\nJail: $jail' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mégsem'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Feloldás'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final ok = await cubit.unbanIp(ip, jail: jail);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? '$ip sikeresen feloldva.' : 'Unban sikertelen.'),
            backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
          ),
        );
      }
    }
  }
}

// ── Filter Bar Widget ─────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.ipController,
    required this.selectedEventType,
    required this.selectedSource,
    required this.resolvedFilter,
    required this.eventTypes,
    required this.sources,
    required this.isWide,
    required this.onEventTypeChanged,
    required this.onSourceChanged,
    required this.onResolvedChanged,
    required this.onIpSearch,
    required this.onClearFilters,
  });

  final TextEditingController ipController;
  final String? selectedEventType;
  final String? selectedSource;
  final bool? resolvedFilter;
  final List<String> eventTypes;
  final List<String> sources;
  final bool isWide;
  final ValueChanged<String?> onEventTypeChanged;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<bool?> onResolvedChanged;
  final VoidCallback onIpSearch;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final filters = [
      // IP keresés
      TextField(
        controller: ipController,
        decoration: InputDecoration(
          hintText: 'IP keresés...',
          prefixIcon: const Icon(LucideIcons.search, size: 16),
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
        onSubmitted: (_) => onIpSearch(),
      ),

      // Event type filter
      _DropdownFilter<String>(
        value: selectedEventType,
        hint: 'Esemény típus',
        items: eventTypes,
        onChanged: onEventTypeChanged,
      ),

      // Source filter
      _DropdownFilter<String>(
        value: selectedSource,
        hint: 'Forrás',
        items: sources,
        onChanged: onSourceChanged,
      ),

      // Resolved filter
      _DropdownFilter<bool>(
        value: resolvedFilter,
        hint: 'Állapot',
        items: const [true, false],
        labels: const {true: 'Lezárt', false: 'Nyitott'},
        onChanged: onResolvedChanged,
      ),

      // Clear
      TextButton.icon(
        icon: const Icon(LucideIcons.x, size: 14),
        label: const Text('Törlés'),
        onPressed: onClearFilters,
      ),
    ];

    if (isWide) {
      return Row(
        children: filters
            .map((f) => Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: f,
                )))
            .toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: filters
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: f,
              ))
          .toList(),
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  const _DropdownFilter({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.labels,
  });

  final T? value;
  final String hint;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final Map<T, String>? labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value:       value,
          hint:        Text(hint, style: const TextStyle(fontSize: 13)),
          isExpanded:  true,
          isDense:     true,
          dropdownColor: AppColors.surface,
          items: [
            DropdownMenuItem<T>(value: null, child: Text(hint, style: const TextStyle(fontSize: 13))),
            ...items.map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labels?[item] ?? item.toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
