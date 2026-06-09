import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../blocs/invitations/invitations_cubit.dart';
import '../../../models/admin_invitation.dart';
import '../../../repositories/invitation_repository.dart';

// ============================================================
// InvitationsScreen – admin meghívók kezelése
// ============================================================

class InvitationsScreen extends StatelessWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InvitationsCubit(repository: InvitationRepository())..load(),
      child: const _InvitationsView(),
    );
  }
}

class _InvitationsView extends StatefulWidget {
  const _InvitationsView();
  @override
  State<_InvitationsView> createState() => _InvitationsViewState();
}

class _InvitationsViewState extends State<_InvitationsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvitationsCubit, InvitationsState>(
      listenWhen: (p, c) =>
          c.error != null && c.error != p.error ||
          c.sendError != null && c.sendError != p.sendError,
      listener: (context, state) {
        final msg = state.sendError ?? state.error;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Row(children: [
            Icon(LucideIcons.userPlus, size: 20),
            SizedBox(width: 8),
            Text('Admin Meghívók'),
          ]),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              onPressed: () => context.read<InvitationsCubit>().load(),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(text: 'Függőben'),
              Tab(text: 'Elfogadva'),
              Tab(text: 'Lejárt'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(LucideIcons.send, size: 18),
          label: const Text('Új meghívó'),
          onPressed: () => _showInviteDialog(context),
        ),
        body: BlocBuilder<InvitationsCubit, InvitationsState>(
          builder: (context, state) {
            if (state.status == InvitationsStatus.loading &&
                state.invitations.isEmpty) {
              return const Center(child: AppLoadingIndicator());
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _InvitationList(items: state.pending),
                _InvitationList(items: state.accepted),
                _InvitationList(items: state.expired),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<InvitationsCubit>(),
        child: const _InviteDialog(),
      ),
    );
  }
}

// ── Meghívó lista ─────────────────────────────────────────────

class _InvitationList extends StatelessWidget {
  final List<AdminInvitation> items;
  const _InvitationList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.inbox, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text('Nincs megjeleníthető meghívó',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white38)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _InvitationTile(item: items[i]),
    );
  }
}

// ── Meghívó kártya ────────────────────────────────────────────

class _InvitationTile extends StatelessWidget {
  final AdminInvitation item;
  const _InvitationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      InvitationStatus.pending  => AppColors.warning,
      InvitationStatus.accepted => AppColors.success,
      InvitationStatus.expired  => AppColors.error,
    };
    final statusLabel = switch (item.status) {
      InvitationStatus.pending  => 'Függőben',
      InvitationStatus.accepted => 'Elfogadva',
      InvitationStatus.expired  => 'Lejárt',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(item.email, style: AppTypography.bodyLarge),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Icon(LucideIcons.shield, size: 13, color: Colors.white38),
          const SizedBox(width: 4),
          Text(item.role, style: AppTypography.bodySmall),
          const SizedBox(width: 16),
          Icon(LucideIcons.clock, size: 13, color: Colors.white38),
          const SizedBox(width: 4),
          Text(
            item.status == InvitationStatus.accepted
                ? 'Elfogadva: ${_fmt(item.acceptedAt!)}'
                : 'Lejár: ${_fmt(item.expiresAt)}',
            style: AppTypography.bodySmall,
          ),
        ]),
        if (item.note != null && item.note!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(item.note!,
              style: AppTypography.bodySmall.copyWith(
                  color: Colors.white38, fontStyle: FontStyle.italic)),
        ],
        if (item.status == InvitationStatus.pending) ...[
          const SizedBox(height: 12),
          Row(children: [
            // Link másolása
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              icon: const Icon(LucideIcons.copy, size: 14),
              label: const Text('Link másolása', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: item.token));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Token vágólapra másolva!')),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            // Visszavonás
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              icon: const Icon(LucideIcons.x, size: 14),
              label: const Text('Visszavonás', style: TextStyle(fontSize: 12)),
              onPressed: () => context
                  .read<InvitationsCubit>()
                  .revokeInvitation(item.id),
            ),
          ]),
        ],
      ]),
    ),
  );
  }

  String _fmt(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Új meghívó dialog ─────────────────────────────────────────

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _emailCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();
  String _selectedRole = 'admin';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvitationsCubit, InvitationsState>(
      listenWhen: (p, c) =>
          !c.isSending && p.isSending && c.sendError == null,
      listener: (context, state) {
        if (state.lastEmailSent == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Meghívó sikeresen elküldve e-mailben!'),
              backgroundColor: Color(0xFF34D399),
            ),
          );
        } else if (state.lastInviteUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Meghívó létrehozva, de e-mail nem ment ki. '
                'Link: ${state.lastInviteUrl}',
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        }
        Navigator.pop(context);
      },
      builder: (context, state) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
          title: const Row(children: [
            Icon(LucideIcons.userPlus, size: 20),
            SizedBox(width: 8),
            Text('Új admin meghívása'),
          ]),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppTextField(
                controller: _emailCtrl,
                label: 'E-mail cím',
                hint: 'admin@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSizes.md),
              // Szerepkör választó
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Szerepkör',
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      borderSide: BorderSide.none),
                ),
                dropdownColor: AppColors.surfaceVariant,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'moderator', child: Text('Moderátor')),
                  DropdownMenuItem(value: 'viewer', child: Text('Megtekintő')),
                ],
                onChanged: (v) => setState(() => _selectedRole = v ?? 'admin'),
              ),
              const SizedBox(height: AppSizes.md),
              AppTextField(
                controller: _noteCtrl,
                label: 'Megjegyzés (opcionális)',
                hint: 'pl. Marketing csapat vezető',
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: state.isSending ? null : () => Navigator.pop(context),
              child: const Text('Mégse'),
            ),
            AppButton(
              label: 'Meghívó küldése',
              isLoading: state.isSending,
              icon: LucideIcons.send,
              onTap: state.isSending
                  ? null
                  : () {
                      final email = _emailCtrl.text.trim();
                      if (email.isEmpty) return;
                      context.read<InvitationsCubit>().sendInvitation(
                            email: email,
                            role: _selectedRole,
                            note: _noteCtrl.text.trim(),
                          );
                    },
            ),
          ],
        );
      },
    );
  }
}
