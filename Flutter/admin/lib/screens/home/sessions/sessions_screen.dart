import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../blocs/sessions/sessions_cubit.dart';
import '../../../blocs/sessions/sessions_state.dart';
import '../../../models/user_session.dart';
import '../../../repositories/session_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/components/components.dart';

// ============================================================
// SessionsScreen – Aktív munkamenet kezelő  [M6]
// ============================================================

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          SessionsCubit(repository: SessionRepository())..load(),
      child: const _SessionsView(),
    );
  }
}

class _SessionsView extends StatelessWidget {
  const _SessionsView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionsCubit, SessionsState>(
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
        final cubit = context.read<SessionsCubit>();
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: const Row(children: [
              Icon(LucideIcons.monitorSmartphone, size: 20),
              SizedBox(width: 8),
              Text('Munkamenetek'),
            ]),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppBadge(
                  label: '${state.activeSessions} aktív',
                  color: AppColors.success,
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: cubit.load,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: state.isLoading && state.sessions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: cubit.load,
                  child: CustomScrollView(
                    slivers: [
                      // ── Statisztika kártyák ─────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.md),
                          child: _StatsRow(state: state),
                        ),
                      ),

                      // ── Megoszlás diagramok ──────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md),
                          child: _BreakdownRow(state: state),
                        ),
                      ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: AppSizes.md)),

                      // ── Session lista ─────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md),
                          child: Text(
                            'Aktív Munkamenetek',
                            style: AppTypography.titleMedium,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: AppSizes.sm)),

                      if (state.sessions.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text('Nincs aktív session.',
                                style: TextStyle(color: Colors.white38)),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final session = state.sessions[index];
                                return _SessionTile(
                                  session:    session,
                                  isRevoking: state.revoking
                                      .contains(session.id),
                                  onRevoke: () => _confirmRevoke(
                                      context, cubit, session),
                                );
                              },
                              childCount: state.sessions.length,
                            ),
                          ),
                        ),

                      const SliverToBoxAdapter(
                          child: SizedBox(height: AppSizes.xl)),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    SessionsCubit cubit,
    UserSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Munkamenet visszavonása'),
        content: Text(
          'Biztosan visszavonod ezt a munkamenetet?\n'
          '\nEszköz: ${session.deviceLabel}'
          '\nHely: ${session.locationLabel}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mégsem'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Visszavonás'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await cubit.revokeSession(session.id);
    }
  }
}

// ── Statisztika sor ───────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final SessionsState state;
  const _StatsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    return Row(children: [
      _StatCard(
        label: 'Aktív session',
        value: '${stats['active_sessions'] ?? state.activeSessions}',
        icon: LucideIcons.monitorSmartphone,
        color: AppColors.success,
      ),
      const SizedBox(width: AppSizes.sm),
      _StatCard(
        label: 'Egyedi felhasználó',
        value: '${stats['unique_users'] ?? '–'}',
        icon: LucideIcons.users,
        color: AppColors.primary,
      ),
      const SizedBox(width: AppSizes.sm),
      _StatCard(
        label: 'Ma bejelentkezett',
        value: '${stats['sessions_today'] ?? '–'}',
        icon: LucideIcons.calendar,
        color: AppColors.primaryVariant,
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: AppTypography.titleLarge.copyWith(color: color)),
          Text(label,
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Megoszlás sor ─────────────────────────────────────────────

class _BreakdownRow extends StatelessWidget {
  final SessionsState state;
  const _BreakdownRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BreakdownCard(
            title: 'OS megoszlás',
            data: state.osBreakdown,
            colors: const [
              Colors.blue, Colors.green, Colors.orange,
              Colors.purple, Colors.red,
            ],
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _BreakdownCard(
            title: 'Verzió megoszlás',
            data: state.versionBreakdown,
            colors: const [
              Colors.teal, Colors.amber, Colors.indigo,
              Colors.pink, Colors.cyan,
            ],
          ),
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  final List<Color> colors;

  const _BreakdownCard({
    required this.title,
    required this.data,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final total  = data.values.fold(0, (a, b) => a + b);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleSmall),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            const Text('Nincs adat',
                style: TextStyle(color: Colors.white38, fontSize: 12))
          else
            ...sorted.asMap().entries.map((e) {
              final idx   = e.key;
              final entry = e.value;
              final pct   = total > 0 ? entry.value / total : 0.0;
              final color = colors[idx % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: color, fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:           pct,
                        backgroundColor: Colors.white12,
                        valueColor:      AlwaysStoppedAnimation<Color>(color),
                        minHeight:       6,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Session tile ──────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final UserSession session;
  final bool isRevoking;
  final VoidCallback onRevoke;

  const _SessionTile({
    required this.session,
    required this.isRevoking,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final osIcon = switch (session.osPlatform) {
      'apple'   => Icons.apple,
      'android' => LucideIcons.smartphone,
      _         => LucideIcons.monitor,
    };

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Icon(osIcon, color: AppColors.primary, size: 22),
        title: Text(session.deviceLabel,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.userEmail ?? session.userId.substring(0, 8),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Row(children: [
              Icon(LucideIcons.mapPin, size: 11, color: Colors.white38),
              const SizedBox(width: 4),
              Text(session.locationLabel,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              if (session.appVersion != null) ...[
                Icon(LucideIcons.code, size: 11, color: Colors.white38),
                const SizedBox(width: 4),
                Text('v${session.appVersion}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ]),
          ],
        ),
        trailing: isRevoking
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: Icon(LucideIcons.logOut,
                    size: 18, color: Colors.red.shade400),
                tooltip: 'Session visszavonása',
                onPressed: onRevoke,
              ),
        isThreeLine: true,
      ),
    );
  }
}
